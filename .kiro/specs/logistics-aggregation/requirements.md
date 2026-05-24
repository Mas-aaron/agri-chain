# Requirements Document

## Introduction

The Logistics Aggregation Module enables smallholder farmers in Uganda to pool their transport demand so that a single truck can serve many farmers along a shared route. Farmers submit pickup locations and destination markets; the system groups nearby farmers heading to the same market into aggregated transport jobs; logistics companies browse and accept those jobs; and the system notifies farmers via SMS when their transport is confirmed.

The module integrates into the existing AgriChain Flutter app (`lib/features/logistics/`) and Go backend (`internal/logistics/`), persisting data in the existing SQLite database via new migration tables.

---

## Glossary

- **Transport_Request_Handler**: The Go HTTP handler responsible for creating, retrieving, and cancelling farmer transport requests via the `/v1/logistics/requests` endpoints.
- **Aggregation_Engine**: The Go component that groups PENDING transport requests into aggregated jobs by geographic corridor and truck capacity.
- **Route_Optimizer**: The Go component that computes an ordered pickup stop sequence for a job using the nearest-neighbour heuristic.
- **Job_Board_Handler**: The Go HTTP handler that exposes aggregated jobs to logistics companies and handles job acceptance and completion.
- **Notification_Handler**: The Go component that sends SMS messages to farmers via the Huawei SMS service when job status changes.
- **Scheduler**: The Go background component that periodically invokes the Aggregation_Engine to process any PENDING requests missed by the per-request trigger.
- **Logistics_Provider**: The Flutter ChangeNotifier that manages transport request and job state for the UI.
- **Logistics_Api_Service**: The Flutter HTTP client that wraps all `/v1/logistics/*` API calls.
- **Transport_Request_Screen**: The Flutter screen where a farmer submits a new transport request.
- **Job_Board_Screen**: The Flutter screen where a logistics company browses open aggregated jobs.
- **Job_Detail_Screen**: The Flutter screen showing route map, stop list, and job acceptance controls.
- **Farmer**: A user with role `farmer` and `kyc_status = approved` who submits transport requests.
- **Logistics_Company**: A user with role `logistics` who browses and accepts aggregated jobs.
- **Corridor**: A combination of `destination_market` and origin region (pickup subcounty) used to group requests.
- **Aggregated_Job**: A transport job created by the Aggregation_Engine grouping multiple farmer requests along a shared corridor.
- **Job_Assignment**: A record created when a logistics company accepts an aggregated job.
- **MIN_FARMERS_PER_JOB**: The minimum number of farmers required to form a viable aggregated job (default: 3).
- **MAX_RADIUS_KM**: The maximum haversine distance between a seed request and any other request in the same cluster (default: 15 km).
- **TRUCK_CAPACITY_KG**: The maximum load per truck used as the default capacity constraint (default: 10,000 kg).
- **AVG_RURAL_SPEED_KMH**: The average Uganda rural road speed used for travel time estimates (40 km/h).
- **Uganda_Bounds**: The geographic bounding box for Uganda: latitude [−1.5, 4.2], longitude [29.5, 35.0].

---

## Requirements

### Requirement 1: Farmer Transport Request Submission

**User Story:** As a farmer, I want to submit a transport request with my pickup location and destination market, so that I can be grouped with other farmers for affordable shared truck transport.

#### Acceptance Criteria

1. WHEN a farmer submits a POST request to `/v1/logistics/requests` with valid `pickup_lat`, `pickup_lng`, `pickup_parish`, `destination_market`, `crop_type`, and `quantity_kg`, THEN THE Transport_Request_Handler SHALL persist the request with `status = PENDING` and return a response containing `request_id`, `status`, and `created_at`.
2. WHEN a transport request is successfully created, THEN THE Transport_Request_Handler SHALL invoke the Aggregation_Engine asynchronously for the request's corridor without blocking the HTTP response.
3. WHEN a farmer submits a GET request to `/v1/logistics/requests/:id` for a request they own, THEN THE Transport_Request_Handler SHALL return the full transport request record including current `status` and `job_id`.
4. IF a farmer submits a GET request to `/v1/logistics/requests/:id` for a request belonging to a different farmer, THEN THE Transport_Request_Handler SHALL return `403 Forbidden`.
5. WHEN a farmer submits a DELETE request to `/v1/logistics/requests/:id` for a request in `PENDING` or `AGGREGATED` status that they own, THEN THE Transport_Request_Handler SHALL transition the request to `CANCELLED` status and return `200 OK`.
6. IF a farmer submits a DELETE request to `/v1/logistics/requests/:id` for a request in `ASSIGNED`, `COMPLETED`, or `CANCELLED` status, THEN THE Transport_Request_Handler SHALL return `400 Bad Request` with error code `REQUEST_NOT_CANCELLABLE`.
7. WHEN a transport request is cancelled from `AGGREGATED` status, THEN THE Transport_Request_Handler SHALL atomically remove the corresponding `job_requests` row and decrement the job's `farmer_count` and `total_quantity_kg` within a single database transaction.
8. WHEN a transport request is cancelled from `AGGREGATED` status, THEN THE Transport_Request_Handler SHALL invoke the Aggregation_Engine asynchronously to re-evaluate the affected job's viability.

---

### Requirement 2: Transport Request Input Validation

**User Story:** As a system operator, I want all transport requests to be validated before persistence, so that the database contains only clean, geographically meaningful data.

#### Acceptance Criteria

1. IF a transport request contains `pickup_lat` outside the range [−1.5, 4.2] or `pickup_lng` outside the range [29.5, 35.0], THEN THE Transport_Request_Handler SHALL return `400 Bad Request` with error code `OUTSIDE_UGANDA_BOUNDS` and reject the request without persisting it.
2. IF a transport request contains `quantity_kg` ≤ 0 or `quantity_kg` > 50,000, THEN THE Transport_Request_Handler SHALL return `400 Bad Request` with error code `VALIDATION_ERROR` and reject the request without persisting it.
3. IF a transport request is missing any required field (`pickup_lat`, `pickup_lng`, `pickup_parish`, `destination_market`, `crop_type`, or `quantity_kg`), THEN THE Transport_Request_Handler SHALL return `400 Bad Request` with error code `VALIDATION_ERROR`.
4. IF a transport request contains a `destination_market` string exceeding 200 characters or a `crop_type` string exceeding 100 characters, THEN THE Transport_Request_Handler SHALL return `400 Bad Request` with error code `VALIDATION_ERROR`.
5. WHILE a farmer does not have `kyc_status = approved`, THE Transport_Request_Handler SHALL reject transport request submissions with `403 Forbidden`.

---

### Requirement 3: Geographic Aggregation Engine

**User Story:** As a farmer, I want my transport request to be automatically grouped with nearby farmers heading to the same market, so that we can share a truck and reduce individual transport costs.

#### Acceptance Criteria

1. WHEN the Aggregation_Engine processes a corridor, THE Aggregation_Engine SHALL query all `PENDING` transport requests sharing the same `destination_market` and origin region.
2. WHEN grouping requests into clusters, THE Aggregation_Engine SHALL include a request in a cluster only if its haversine distance from the cluster seed is ≤ MAX_RADIUS_KM (15 km).
3. WHEN building a cluster, THE Aggregation_Engine SHALL include a request only if adding its `quantity_kg` to the cluster's running total does not exceed TRUCK_CAPACITY_KG (10,000 kg).
4. IF a cluster contains fewer than MIN_FARMERS_PER_JOB (3) requests, THEN THE Aggregation_Engine SHALL NOT create an aggregated job for that cluster and SHALL leave those requests in `PENDING` status.
5. WHEN a viable cluster (≥ MIN_FARMERS_PER_JOB requests) is formed, THE Aggregation_Engine SHALL atomically create an `aggregated_jobs` record, insert corresponding `job_requests` rows, and update all clustered `transport_requests` to `status = AGGREGATED` with the new `job_id` within a single database transaction.
6. THE Aggregation_Engine SHALL ensure that no transport request is assigned to more than one aggregated job simultaneously.
7. WHEN creating an aggregated job, THE Aggregation_Engine SHALL compute and store the geographic centroid of the cluster's pickup coordinates as `centroid_lat` and `centroid_lng`.
8. WHEN creating an aggregated job, THE Aggregation_Engine SHALL invoke the Route_Optimizer to compute the ordered stop sequence and store the result as `route_json` on the job record.

---

### Requirement 4: Route Optimisation

**User Story:** As a logistics company driver, I want an optimised pickup route for each job, so that I can collect all farmers efficiently with minimal travel distance.

#### Acceptance Criteria

1. WHEN the Route_Optimizer is invoked with a list of pickup stops, THE Route_Optimizer SHALL return an ordered stop sequence that is a permutation of the input stops — containing exactly the same stops with no additions or omissions.
2. WHEN computing the route, THE Route_Optimizer SHALL start from the stop closest to the geographic centroid of the cluster and apply a nearest-neighbour heuristic to sequence subsequent stops.
3. WHEN the Route_Optimizer produces a RouteResult, THE Route_Optimizer SHALL set `total_distance_km` equal to the sum of haversine distances between consecutive stops in the ordered sequence.
4. WHEN the Route_Optimizer produces a RouteResult, THE Route_Optimizer SHALL set `estimated_hours` equal to `total_distance_km` divided by AVG_RURAL_SPEED_KMH (40 km/h).
5. WHEN the Route_Optimizer assigns stop order indices, THE Route_Optimizer SHALL assign sequential integer values starting at 1 with no gaps (1, 2, 3, … N).
6. IF the Route_Optimizer receives a single-stop input, THE Route_Optimizer SHALL return that stop unchanged with `stop_order = 1`, `total_distance_km = 0`, and `estimated_hours = 0`.
7. WHEN a transport request is cancelled from an aggregated job that retains ≥ MIN_FARMERS_PER_JOB remaining requests, THE Route_Optimizer SHALL recompute the route with the remaining stops and update `route_json` on the job record.

---

### Requirement 5: Haversine Distance Calculation

**User Story:** As a developer, I want a correct haversine distance implementation, so that geographic clustering and route optimisation produce accurate results for Uganda's coordinate space.

#### Acceptance Criteria

1. THE Route_Optimizer SHALL compute distances between coordinate pairs using the haversine formula with Earth radius 6,371 km.
2. FOR ALL coordinate pairs (a, b), THE Route_Optimizer SHALL produce `HaversineKm(a, b) = HaversineKm(b, a)` (symmetry).
3. FOR ALL coordinate pairs, THE Route_Optimizer SHALL produce `HaversineKm(a, b) ≥ 0` (non-negativity).
4. WHEN both coordinate pairs are identical, THE Route_Optimizer SHALL produce `HaversineKm(a, a) = 0`.

---

### Requirement 6: Job Board for Logistics Companies

**User Story:** As a logistics company, I want to browse aggregated transport jobs and accept ones that match my truck capacity, so that I can plan profitable multi-stop routes serving multiple farmers.

#### Acceptance Criteria

1. WHEN a logistics company sends a GET request to `/v1/logistics/jobs`, THE Job_Board_Handler SHALL return a paginated list of aggregated jobs including `farmer_count`, `total_quantity_kg`, `destination_market`, `origin_region`, `status`, and route summary for each job.
2. WHEN the job list request includes a `status` query parameter, THE Job_Board_Handler SHALL filter results to jobs matching that status value.
3. WHEN the job list request includes a `market` query parameter, THE Job_Board_Handler SHALL filter results to jobs matching that `destination_market`.
4. WHEN the job list request includes a `min_kg` query parameter, THE Job_Board_Handler SHALL filter results to jobs whose `total_quantity_kg` is ≥ the specified value.
5. THE Job_Board_Handler SHALL support `limit` (default 20, max 100) and `offset` query parameters for pagination.
6. WHEN a logistics company sends a POST request to `/v1/logistics/jobs/:id/accept` with valid `company_id`, `truck_capacity_kg`, and `driver_phone`, and the job has `status = OPEN`, THE Job_Board_Handler SHALL atomically transition the job to `status = ASSIGNED`, create a `job_assignments` record, and update all linked `transport_requests` to `status = ASSIGNED` within a single database transaction.
7. IF a logistics company attempts to accept a job where `truck_capacity_kg` < `job.total_quantity_kg`, THEN THE Job_Board_Handler SHALL return `400 Bad Request` with error code `CAPACITY_INSUFFICIENT`.
8. IF two logistics companies attempt to accept the same job concurrently and the job is already `ASSIGNED`, THEN THE Job_Board_Handler SHALL return `409 Conflict` with error code `JOB_ALREADY_ASSIGNED` to the second caller.
9. WHEN a job is successfully accepted, THE Job_Board_Handler SHALL trigger the Notification_Handler to send SMS messages to all farmers in the job as a non-blocking goroutine after the database transaction commits.
10. WHEN a driver sends a POST request to `/v1/logistics/jobs/:id/complete` with valid `company_id`, THE Job_Board_Handler SHALL transition the job from `IN_TRANSIT` to `COMPLETED` status and update all linked `transport_requests` to `status = COMPLETED`.
11. THE Job_Board_Handler SHALL omit individual farmer phone numbers from the job list response; farmer phone numbers SHALL only be included in the job detail response after the job is `ASSIGNED`.

---

### Requirement 7: Job Status State Machine

**User Story:** As a system operator, I want strict status transition rules enforced for both transport requests and aggregated jobs, so that the system state is always consistent and auditable.

#### Acceptance Criteria

1. THE Transport_Request_Handler SHALL only permit the following status transitions for transport requests: `PENDING → AGGREGATED`, `AGGREGATED → ASSIGNED`, `ASSIGNED → COMPLETED`, `PENDING → CANCELLED`, `AGGREGATED → CANCELLED`, and `AGGREGATED → PENDING` (job dissolved).
2. THE Job_Board_Handler SHALL only permit the following status transitions for aggregated jobs: `OPEN → ASSIGNED`, `ASSIGNED → IN_TRANSIT`, `IN_TRANSIT → COMPLETED`, and `OPEN → CANCELLED`.
3. IF any component attempts a status transition not listed in criteria 1 or 2, THEN THE system SHALL reject the transition and return an appropriate error without modifying the record.
4. WHEN an aggregated job transitions to `CANCELLED`, THE Aggregation_Engine SHALL revert all `AGGREGATED` transport requests linked to that job to `PENDING` status with `job_id = NULL` within the same database transaction.
5. WHEN an aggregated job is cancelled, THE Aggregation_Engine SHALL ensure no transport request remains in `AGGREGATED` status with a reference to the cancelled job.

---

### Requirement 8: Job Viability Re-evaluation

**User Story:** As a farmer, I want the system to automatically dissolve under-subscribed jobs when cancellations reduce farmer count below the minimum, so that logistics companies are never presented with unviable jobs.

#### Acceptance Criteria

1. WHEN a transport request is cancelled from `AGGREGATED` status, THE Aggregation_Engine SHALL asynchronously re-evaluate the viability of the affected job.
2. IF the affected job's remaining `farmer_count` drops below MIN_FARMERS_PER_JOB after cancellation, THEN THE Aggregation_Engine SHALL dissolve the job by transitioning it to `CANCELLED` and reverting all remaining `AGGREGATED` requests to `PENDING` with `job_id = NULL`.
3. IF the affected job's remaining `farmer_count` is ≥ MIN_FARMERS_PER_JOB after cancellation, THEN THE Aggregation_Engine SHALL recompute the route with the remaining stops and update `route_json` on the job record.
4. THE Aggregation_Engine SHALL only re-evaluate jobs in `OPEN` status; jobs in `ASSIGNED` or later status SHALL NOT be dissolved by cancellation.
5. WHEN a job is dissolved, THE Aggregation_Engine SHALL ensure no `job_requests` row remains linking any request to the dissolved job.

---

### Requirement 9: SMS Notifications via Huawei SMS

**User Story:** As a farmer, I want to receive an SMS notification when my transport job is confirmed, so that I know when and where to bring my produce for pickup.

#### Acceptance Criteria

1. WHEN a job is accepted by a logistics company, THE Notification_Handler SHALL send an SMS to each farmer in the job containing the farmer's crop type, the job reference ID, the planned pickup date, and the driver's phone number.
2. THE Notification_Handler SHALL use the message template: `"AgriChain: Your {crop} transport (Job {job_id}) is confirmed. Pickup: {date}. Driver: {phone}."`.
3. THE Notification_Handler SHALL send SMS messages via the existing Huawei SMS service using the `HUAWEI_SMS_*` environment variables.
4. IF the Huawei SMS service returns an error for one or more farmer phone numbers, THEN THE Notification_Handler SHALL log the failure with the affected farmer IDs and SHALL NOT block or roll back the job acceptance transaction.
5. WHEN a job transitions to `COMPLETED`, THE Notification_Handler SHALL send an SMS notification to all farmers in the job confirming delivery completion.
6. THE Notification_Handler SHALL NOT include sensitive financial data in SMS message content.

---

### Requirement 10: Background Aggregation Scheduler

**User Story:** As a system operator, I want a background scheduler to periodically re-run aggregation, so that transport requests are not left unaggregated due to server restarts or transient aggregation errors.

#### Acceptance Criteria

1. THE Scheduler SHALL invoke `RunFullAggregation` on the Aggregation_Engine at a configurable interval (default: every 15 minutes).
2. WHEN `RunFullAggregation` is invoked, THE Aggregation_Engine SHALL query all distinct corridors with `PENDING` requests and run the grouping algorithm for each corridor.
3. IF the Aggregation_Engine returns an error for a specific corridor during a full sweep, THEN THE Scheduler SHALL log the error and continue processing remaining corridors without crashing.
4. WHEN the server receives a shutdown signal, THE Scheduler SHALL stop processing new ticks and allow the current aggregation sweep to complete before exiting.
5. THE Scheduler SHALL be started during server initialisation and stopped during graceful server shutdown.

---

### Requirement 11: Flutter Farmer UI — Transport Request Screen

**User Story:** As a farmer, I want a mobile screen to submit and track my transport requests, so that I can easily participate in the logistics aggregation system from my phone.

#### Acceptance Criteria

1. THE Transport_Request_Screen SHALL provide input fields for pickup location (map pin picker using device GPS), destination market, crop type, quantity in kg, and optional harvest ready date and notes.
2. WHEN a farmer pins their pickup location on the map, THE Transport_Request_Screen SHALL populate `pickup_lat`, `pickup_lng`, and `pickup_parish` from the selected coordinates.
3. WHEN a farmer submits the form with valid data, THE Transport_Request_Screen SHALL call the Logistics_Api_Service to POST the request and display the returned `status` and `request_id` to the farmer.
4. IF the API returns a validation error (e.g., `OUTSIDE_UGANDA_BOUNDS`), THEN THE Transport_Request_Screen SHALL display an inline error message on the relevant field without dismissing the form.
5. THE Transport_Request_Screen SHALL display the current status of the farmer's most recent request and update it when the status changes (e.g., from `PENDING` to `AGGREGATED`).
6. WHEN a farmer's request is in `PENDING` or `AGGREGATED` status, THE Transport_Request_Screen SHALL provide a cancel button that calls the DELETE endpoint.

---

### Requirement 12: Flutter Logistics UI — Job Board Screen

**User Story:** As a logistics company, I want a mobile screen to browse available transport jobs, so that I can identify profitable routes and accept jobs that match my truck capacity.

#### Acceptance Criteria

1. THE Job_Board_Screen SHALL display a list of aggregated jobs with `farmer_count`, `total_quantity_kg`, `destination_market`, `origin_region`, and job `status` for each entry.
2. WHEN the Job_Board_Screen loads, THE Logistics_Provider SHALL fetch open jobs from `GET /v1/logistics/jobs?status=OPEN` and populate the list.
3. THE Job_Board_Screen SHALL provide filter controls for `status`, `destination_market`, and minimum quantity.
4. WHEN a logistics company taps a job entry, THE Job_Board_Screen SHALL navigate to the Job_Detail_Screen for that job.
5. THE Job_Board_Screen SHALL support pull-to-refresh to reload the job list.

---

### Requirement 13: Flutter Logistics UI — Job Detail Screen

**User Story:** As a logistics company driver, I want to see the full route map and stop list for a job before accepting it, so that I can assess the route feasibility and plan my schedule.

#### Acceptance Criteria

1. THE Job_Detail_Screen SHALL display a map showing all pickup stop markers and a polyline connecting them in the optimised route order.
2. THE Job_Detail_Screen SHALL display a scrollable list of route stops showing `stop_order`, `farmer_name`, `parish`, `lat`, `lng`, and `quantity_kg` for each stop.
3. THE Job_Detail_Screen SHALL display the job's `total_distance_km` and `estimated_hours`.
4. WHEN the job has `status = OPEN`, THE Job_Detail_Screen SHALL display an accept button that opens a form for `truck_capacity_kg`, `driver_phone`, and `planned_pickup_at`.
5. WHEN a logistics company submits the accept form, THE Job_Detail_Screen SHALL call the Logistics_Api_Service to POST to `/v1/logistics/jobs/:id/accept` and display the result status.
6. IF the accept call returns `409 Conflict`, THEN THE Job_Detail_Screen SHALL display a message indicating the job was already accepted and refresh the job status.
7. WHEN the job has more than 20 stops, THE Job_Detail_Screen SHALL cluster map markers at zoom levels below 12 to maintain rendering performance.

---

### Requirement 14: Data Persistence — SQLite Schema and Migrations

**User Story:** As a developer, I want the logistics data persisted in the existing SQLite database via versioned migrations, so that the schema is reproducible and upgradeable without data loss.

#### Acceptance Criteria

1. THE system SHALL create a `transport_requests` table with columns: `id` (TEXT PRIMARY KEY, format `TR-<hex12>`), `farmer_uid`, `farmer_name`, `farmer_phone`, `pickup_lat`, `pickup_lng`, `pickup_parish`, `pickup_subcounty`, `destination_market`, `crop_type`, `quantity_kg` (CHECK > 0), `harvest_ready_at`, `farmer_notes`, `status` (DEFAULT `PENDING`), `job_id`, `created_at`, `updated_at`.
2. THE system SHALL create an `aggregated_jobs` table with columns: `id` (TEXT PRIMARY KEY, format `JOB-<hex12>`), `destination_market`, `origin_region`, `total_quantity_kg`, `farmer_count`, `status` (DEFAULT `OPEN`), `route_json`, `centroid_lat`, `centroid_lng`, `created_at`, `updated_at`.
3. THE system SHALL create a `job_requests` join table with columns: `job_id`, `request_id`, `added_at`, with a composite PRIMARY KEY `(job_id, request_id)` and CASCADE DELETE foreign keys to both parent tables.
4. THE system SHALL create a `job_assignments` table with columns: `id` (TEXT PRIMARY KEY, format `ASN-<hex12>`), `job_id`, `company_id`, `driver_phone`, `truck_capacity_kg`, `planned_pickup_at`, `accepted_at`, `status` (DEFAULT `ACTIVE`).
5. THE system SHALL create indexes on `transport_requests(status)`, `transport_requests(destination_market)`, `transport_requests(farmer_uid)`, `transport_requests(job_id)`, `aggregated_jobs(status)`, `aggregated_jobs(destination_market)`, and `job_requests(request_id)`.
6. THE system SHALL enforce a FOREIGN KEY from `transport_requests.farmer_uid` to `users.uid` with `ON DELETE CASCADE`.
7. THE system SHALL enforce a FOREIGN KEY from `transport_requests.job_id` to `aggregated_jobs.id` with `ON DELETE SET NULL`.
8. THE system SHALL apply the schema via the existing SQLite migration mechanism so that the tables are created idempotently (`CREATE TABLE IF NOT EXISTS`).

---

### Requirement 15: Flutter Data Models

**User Story:** As a Flutter developer, I want strongly-typed Dart models for all logistics entities, so that the UI layer can safely consume and display API responses.

#### Acceptance Criteria

1. THE Logistics_Api_Service SHALL provide a `TransportRequest` Dart model with fields: `id`, `farmerUid`, `farmerName`, `pickupLat`, `pickupLng`, `pickupParish`, `destinationMarket`, `cropType`, `quantityKg`, `status`, `jobId` (nullable), and `createdAt`.
2. THE Logistics_Api_Service SHALL provide an `AggregatedJob` Dart model with fields: `id`, `destinationMarket`, `originRegion`, `totalQuantityKg`, `farmerCount`, `status`, `route` (nullable `RouteResult`), `centroidLat` (nullable), `centroidLng` (nullable), and `createdAt`.
3. THE Logistics_Api_Service SHALL provide a `RouteResult` Dart model with fields: `orderedStops` (list of `RouteStop`), `totalDistanceKm`, and `estimatedHours`.
4. THE Logistics_Api_Service SHALL provide a `RouteStop` Dart model with fields: `stopOrder`, `requestId`, `farmerName`, `parish`, `lat`, `lng`, and `quantityKg`.
5. FOR ALL Dart models, THE Logistics_Api_Service SHALL implement `fromJson` factory constructors and `toJson` methods that round-trip correctly — parsing then serialising then parsing SHALL produce an equivalent object.

---

### Requirement 16: API Error Handling

**User Story:** As a Flutter developer, I want consistent, structured error responses from all logistics endpoints, so that the app can display meaningful error messages to users.

#### Acceptance Criteria

1. THE Transport_Request_Handler SHALL return all error responses using the existing `response.ErrorResponse` envelope format: `{"error": {"code": "...", "message": "...", "details": {...}}}`.
2. THE Job_Board_Handler SHALL return `400 Bad Request` with code `CAPACITY_INSUFFICIENT` when a logistics company attempts to accept a job with insufficient truck capacity, including the job's `total_quantity_kg` and the submitted `truck_capacity_kg` in the `details` field.
3. THE Job_Board_Handler SHALL return `409 Conflict` with code `JOB_ALREADY_ASSIGNED` when a job has already been accepted by another company.
4. THE Transport_Request_Handler SHALL return `400 Bad Request` with code `REQUEST_NOT_CANCELLABLE` when a farmer attempts to cancel a request in `ASSIGNED` or later status.
5. THE Transport_Request_Handler SHALL return `400 Bad Request` with code `OUTSIDE_UGANDA_BOUNDS` when submitted coordinates fall outside Uganda's bounding box, including the submitted coordinate values in the `details` field.
6. THE Transport_Request_Handler SHALL return `403 Forbidden` with code `FORBIDDEN` when a farmer attempts to access or cancel another farmer's request.

---

### Requirement 17: Security and Access Control

**User Story:** As a system operator, I want role-based access control enforced on all logistics endpoints, so that farmers cannot accept jobs and logistics companies cannot view other farmers' personal data.

#### Acceptance Criteria

1. THE Transport_Request_Handler SHALL require role `farmer` or `admin` for POST, GET, and DELETE requests to `/v1/logistics/requests`.
2. THE Job_Board_Handler SHALL require role `logistics` or `admin` for POST requests to `/v1/logistics/jobs/:id/accept` and `/v1/logistics/jobs/:id/complete`.
3. THE Job_Board_Handler SHALL permit unauthenticated or any-role GET requests to `/v1/logistics/jobs` for the public job listing.
4. THE Transport_Request_Handler SHALL apply the existing `middleware.RequireKYCApproved(db)` check to transport request submission, rejecting farmers without `kyc_status = approved`.
5. THE Transport_Request_Handler SHALL apply the existing `middleware.Idempotency` middleware (10-minute window) to `POST /v1/logistics/requests` to prevent duplicate submissions from network retries.
6. THE Job_Board_Handler SHALL apply the existing `middleware.Idempotency` middleware to `POST /v1/logistics/jobs/:id/accept` to prevent duplicate acceptance from network retries.
7. THE Job_Board_Handler SHALL omit farmer phone numbers from job list responses; farmer phone numbers SHALL only be returned in job detail responses after the job status is `ASSIGNED`.
