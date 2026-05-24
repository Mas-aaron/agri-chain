# Implementation Plan: Logistics Aggregation Module

## Overview

Implement the full logistics aggregation feature for AgriChain: SQLite schema migration, Go backend (models, store, aggregation engine, route optimizer, haversine, handlers, scheduler), and Flutter frontend (models, API service, provider, screens). Tasks are ordered backend-first, then Flutter, with each task building on the previous.

## Tasks

- [ ] 1. SQLite migration — add logistics tables
  - [ ] 1.1 Add logistics tables to `db.Migrate()` in `agri-chain/server/internal/storage/sqlite/db.go`
    - Append `CREATE TABLE IF NOT EXISTS transport_requests (...)` with all columns, CHECK constraint on `quantity_kg`, and FK to `users(uid) ON DELETE CASCADE` and `aggregated_jobs(id) ON DELETE SET NULL`
    - Append `CREATE TABLE IF NOT EXISTS aggregated_jobs (...)` with all columns
    - Append `CREATE TABLE IF NOT EXISTS job_requests (...)` with composite PK and CASCADE FK to both parent tables
    - Append `CREATE TABLE IF NOT EXISTS job_assignments (...)` with all columns
    - Append all seven `CREATE INDEX IF NOT EXISTS` statements for the new tables
    - _Requirements: 14.1, 14.2, 14.3, 14.4, 14.5, 14.6, 14.7, 14.8_

- [ ] 2. Go — core types and logistics store
  - [ ] 2.1 Create `agri-chain/server/internal/logistics/types.go`
    - Define Go structs: `TransportRequest`, `AggregatedJob`, `JobAssignment`, `JobRequest`, `RouteResult`, `RouteStop`
    - Define `TransportRequestInput`, `TransportRequestResponse`, `JobListQuery`, `JobAcceptInput`, `JobCompleteInput`
    - Define status constants: `StatusPending`, `StatusAggregated`, `StatusAssigned`, `StatusInTransit`, `StatusCompleted`, `StatusCancelled`, `StatusOpen`
    - Define error code constants: `ErrCodeOutsideUgandaBounds`, `ErrCodeValidationError`, `ErrCodeCapacityInsufficient`, `ErrCodeJobAlreadyAssigned`, `ErrCodeRequestNotCancellable`, `ErrCodeForbidden`
    - _Requirements: 1.1, 2.1, 6.1, 7.1, 7.2_
  - [ ] 2.2 Create `agri-chain/server/internal/logistics/store.go`
    - Implement `LogisticsStore` interface with methods: `CreateTransportRequest`, `GetTransportRequest`, `UpdateTransportRequestStatus`, `CancelTransportRequest` (atomic job_requests delete + job counters decrement in one tx), `ListPendingByCorridors`, `CreateAggregatedJob`, `GetAggregatedJob`, `UpdateJobStatus`, `UpdateJobRoute`, `GetJobRequests`, `InsertJobRequests`, `DeleteJobRequests`, `CreateJobAssignment`, `ListJobs`
    - Use `*sqlite.DB` as the backing store; generate IDs with `TR-<hex12>`, `JOB-<hex12>`, `ASN-<hex12>` format
    - _Requirements: 1.1, 1.3, 1.5, 1.7, 6.1, 6.6, 14.1, 14.2, 14.3, 14.4_

- [ ] 3. Go — haversine and route optimizer
  - [ ] 3.1 Create `agri-chain/server/internal/logistics/haversine.go`
    - Implement `haversineKm(lat1, lng1, lat2, lng2 float64) float64` using Earth radius 6371 km
    - Implement `computeCentroid(requests []TransportRequest) (lat, lng float64)` as arithmetic mean of coordinates
    - _Requirements: 5.1, 5.2, 5.3, 5.4_
  - [ ]* 3.2 Write property tests for haversine in `agri-chain/server/internal/logistics/haversine_test.go`
    - **Property 5: Distance Symmetry** — `haversineKm(a,b) == haversineKm(b,a)` for all coordinate pairs using `testing/quick`
    - **Property 6: Distance Non-Negativity** — `haversineKm(a,b) >= 0` for all inputs; equals 0 when `a == b`
    - **Validates: Requirements 5.2, 5.3, 5.4**
  - [ ] 3.3 Create `agri-chain/server/internal/logistics/route_optimizer.go`
    - Implement `RouteOptimizer` interface and `nearestNeighbourOptimizer` struct
    - Implement `OptimizeRoute(ctx, job, requests)` using nearest-neighbour heuristic starting from centroid
    - Assign sequential `stop_order` values starting at 1; compute `total_distance_km` as sum of consecutive haversine distances; set `estimated_hours = total_distance_km / 40`
    - Handle single-stop edge case: return stop unchanged with `stop_order=1`, `total_distance_km=0`, `estimated_hours=0`
    - _Requirements: 4.1, 4.2, 4.3, 4.4, 4.5, 4.6_
  - [ ]* 3.4 Write property tests for route optimizer in `agri-chain/server/internal/logistics/route_optimizer_test.go`
    - **Property 4: Route Permutation** — `OptimizeRoute` output is a permutation of input stops (same elements, no additions or omissions) using `testing/quick`
    - **Validates: Requirements 4.1**
    - Also write unit tests: single-stop input, sequential stop_order (1..N), `total_distance_km` equals sum of consecutive haversine distances
    - _Requirements: 4.1, 4.5, 4.6_

- [ ] 4. Go — aggregation engine
  - [ ] 4.1 Create `agri-chain/server/internal/logistics/aggregation_engine.go`
    - Implement `AggregationEngine` interface with `TriggerAggregation(ctx, destinationMarket, pickupParish)` and `RunFullAggregation(ctx)`
    - Implement `aggregationEngine` struct with fields `db`, `routeOptimizer`, `maxRadiusKm` (default 15), `minFarmersToJob` (default 3), `truckCapacityKg` (default 10000)
    - Implement `groupRequestsByCorridor(requests, maxRadiusKm, truckCapacityKg)` using the greedy seed-based clustering algorithm from the design pseudocode
    - In `TriggerAggregation`: query PENDING requests for corridor, run grouping, atomically create `aggregated_jobs` + `job_requests` rows + update `transport_requests` to `AGGREGATED` in a single DB transaction, then call `OptimizeRoute` and store `route_json`
    - In `RunFullAggregation`: query all distinct corridors with PENDING requests, call `TriggerAggregation` per corridor, log errors per corridor without stopping
    - Implement `ReEvaluateJobViability(ctx, jobID)`: if `farmer_count < minFarmersToJob` dissolve job (cancel job, revert requests to PENDING, delete job_requests); otherwise recompute route
    - _Requirements: 3.1, 3.2, 3.3, 3.4, 3.5, 3.6, 3.7, 3.8, 7.4, 7.5, 8.1, 8.2, 8.3, 8.4, 8.5, 10.2_
  - [ ]* 4.2 Write property tests for aggregation engine in `agri-chain/server/internal/logistics/aggregation_engine_test.go`
    - **Property 1: Capacity Invariant** — no job's `total_quantity_kg` exceeds `truckCapacityKg` for any generated input using `testing/quick`
    - **Property 2: No Double-Assignment** — no request ID appears in more than one job for any generated input
    - **Property 3: Aggregation Completeness** — every request in a returned job satisfies the radius constraint from the seed
    - **Validates: Requirements 3.2, 3.3, 3.6**
  - [ ]* 4.3 Write unit tests for aggregation engine in `agri-chain/server/internal/logistics/aggregation_engine_test.go`
    - `TestGroupRequestsByCorridor_SmallClusterNotPromoted`: cluster below `minFarmersToJob` produces no job
    - `TestGroupRequestsByCorridor_CapacityRespected`: requests exceeding capacity are excluded from cluster
    - `TestReEvaluateJobViability_Dissolves`: job with 1 remaining farmer is cancelled; requests revert to PENDING
    - `TestReEvaluateJobViability_Recomputes`: job with ≥ `minFarmersToJob` farmers gets route recomputed
    - `TestReEvaluateJobViability_SkipsAssignedJob`: job in ASSIGNED status is not dissolved
    - _Requirements: 3.4, 8.2, 8.3, 8.4_

- [ ] 5. Go — notification handler
  - [ ] 5.1 Create `agri-chain/server/internal/logistics/notification_handler.go`
    - Implement `NotificationHandler` interface with `NotifyJobAccepted(ctx, job, assignment, farmers)` and `NotifyJobCompleted(ctx, job, farmers)`
    - Implement `smsNotifier` struct wrapping the existing Huawei SMS client (read `HUAWEI_SMS_*` env vars)
    - Compose SMS using template: `"AgriChain: Your {crop} transport (Job {job_id}) is confirmed. Pickup: {date}. Driver: {phone}."`
    - For `NotifyJobCompleted`, send delivery confirmation SMS to all farmers
    - Log failed deliveries with farmer IDs; do not return error to caller (non-blocking contract)
    - Do not include sensitive financial data in SMS content
    - _Requirements: 9.1, 9.2, 9.3, 9.4, 9.5, 9.6_
  - [ ]* 5.2 Write unit tests for notification handler in `agri-chain/server/internal/logistics/notification_handler_test.go`
    - Test SMS message template rendering for `NotifyJobAccepted` and `NotifyJobCompleted`
    - Test that SMS failure for one farmer does not prevent other farmers from being notified
    - Use a mock `HuaweiSMSClient` that returns configurable errors
    - _Requirements: 9.1, 9.2, 9.4_

- [ ] 6. Go — background scheduler
  - [ ] 6.1 Create `agri-chain/server/internal/logistics/scheduler.go`
    - Implement `Scheduler` struct with `engine AggregationEngine`, `interval time.Duration`, `logger *log.Logger`, and internal `stop chan struct{}`
    - Implement `NewScheduler(engine, interval) *Scheduler`
    - Implement `Start(ctx context.Context)`: launch goroutine with `time.NewTicker(s.interval)`; on each tick call `engine.RunFullAggregation(ctx)`; log errors per corridor; respect context cancellation and `Stop()` signal
    - Implement `Stop()`: close stop channel; allow current sweep to complete before returning
    - _Requirements: 10.1, 10.3, 10.4, 10.5_
  - [ ]* 6.2 Write unit tests for scheduler in `agri-chain/server/internal/logistics/scheduler_test.go`
    - Test that `RunFullAggregation` is called on each tick
    - Test that a corridor error does not stop subsequent ticks
    - Test graceful shutdown: `Stop()` prevents new ticks after being called
    - _Requirements: 10.1, 10.3, 10.4_

- [ ] 7. Go — transport request handler
  - [ ] 7.1 Create `agri-chain/server/internal/logistics/handler.go` — `LogisticsHandler` struct and constructor
    - Define `LogisticsHandler` struct with fields `store LogisticsStore`, `engine AggregationEngine`, `notifier NotificationHandler`
    - Implement `NewLogisticsHandler(db *sqlite.DB, engine AggregationEngine, notifier NotificationHandler) *LogisticsHandler`
    - Implement `validateTransportRequest(req TransportRequestInput) error`: check Uganda bounds [−1.5,4.2] / [29.5,35.0], `quantity_kg` in (0, 50000], non-empty required fields, string length limits; return `response.ErrorResponse` with appropriate error codes
    - _Requirements: 2.1, 2.2, 2.3, 2.4, 16.1, 16.5_
  - [ ] 7.2 Implement `createRequest` handler in `handler.go`
    - Bind and validate `TransportRequestInput`; extract `farmer_uid`, `farmer_name`, `farmer_phone` from auth context
    - Persist to `transport_requests` with `status=PENDING`; return `TransportRequestResponse` with `request_id`, `status`, `created_at`
    - Fire-and-forget goroutine: `go engine.TriggerAggregation(context.Background(), input.DestinationMarket, input.PickupParish)`
    - Apply `middleware.RequireKYCApproved(db)` via route group (not inline); return `403` if KYC not approved
    - _Requirements: 1.1, 1.2, 2.5, 17.1, 17.4, 17.5_
  - [ ] 7.3 Implement `getRequest` and `cancelRequest` handlers in `handler.go`
    - `getRequest`: fetch by ID; verify `farmer_uid == auth.UID`; return full record including `status` and `job_id`; return `403` if ownership mismatch
    - `cancelRequest`: verify ownership; check status is PENDING or AGGREGATED (return `400 REQUEST_NOT_CANCELLABLE` otherwise); atomically cancel request, delete `job_requests` row, decrement job counters in one DB transaction; fire-and-forget `ReEvaluateJobViability`
    - _Requirements: 1.3, 1.4, 1.5, 1.6, 1.7, 1.8, 7.1, 16.4, 16.6_
  - [ ]* 7.4 Write unit tests for transport request handler in `agri-chain/server/internal/logistics/handler_test.go`
    - `TestValidateTransportRequest_OutOfBounds`: lat/lng outside Uganda returns `OUTSIDE_UGANDA_BOUNDS`
    - `TestValidateTransportRequest_ZeroQuantity`: `quantity_kg=0` returns `VALIDATION_ERROR`
    - `TestValidateTransportRequest_MissingFields`: missing required fields return `VALIDATION_ERROR`
    - `TestCancelRequest_AssignedRequest`: returns `400 REQUEST_NOT_CANCELLABLE`
    - `TestGetRequest_WrongFarmer`: returns `403 FORBIDDEN`
    - _Requirements: 2.1, 2.2, 2.3, 1.4, 1.6_

- [ ] 8. Go — job board handler
  - [ ] 8.1 Implement `listJobs` handler in `handler.go`
    - Bind `JobListQuery` (status, market, min_kg, limit, offset); default limit=20, max limit=100
    - Query `aggregated_jobs` with optional filters; return paginated list with `farmer_count`, `total_quantity_kg`, `destination_market`, `origin_region`, `status`, route summary
    - Omit individual farmer phone numbers from list response
    - Allow unauthenticated access (public read)
    - _Requirements: 6.1, 6.2, 6.3, 6.4, 6.5, 17.3, 17.7_
  - [ ] 8.2 Implement `acceptJob` handler in `handler.go`
    - Bind `JobAcceptInput`; require role `logistics` or `admin`
    - Validate `truck_capacity_kg >= job.total_quantity_kg`; return `400 CAPACITY_INSUFFICIENT` with details if not
    - Begin DB transaction: SELECT job FOR UPDATE, check `status=OPEN` (return `409 JOB_ALREADY_ASSIGNED` if not), UPDATE job to `ASSIGNED`, INSERT `job_assignments`, UPDATE all linked `transport_requests` to `ASSIGNED`; COMMIT
    - After commit, fire-and-forget goroutine: `go notifier.NotifyJobAccepted(...)`
    - _Requirements: 6.6, 6.7, 6.8, 6.9, 7.2, 16.2, 16.3, 17.2, 17.6_
  - [ ] 8.3 Implement `completeJob` handler in `handler.go`
    - Bind `JobCompleteInput`; require role `logistics` or `admin`
    - Transition job from `IN_TRANSIT` to `COMPLETED`; update all linked `transport_requests` to `COMPLETED`
    - Fire-and-forget goroutine: `go notifier.NotifyJobCompleted(...)`
    - _Requirements: 6.10, 7.2_
  - [ ]* 8.4 Write unit tests for job board handler in `agri-chain/server/internal/logistics/handler_test.go`
    - `TestAcceptJob_CapacityInsufficient`: returns `400 CAPACITY_INSUFFICIENT` with `total_quantity_kg` and `truck_capacity_kg` in details
    - `TestAcceptJob_AlreadyAssigned`: returns `409 JOB_ALREADY_ASSIGNED`
    - `TestListJobs_FiltersApplied`: status, market, and min_kg filters return correct subsets
    - `TestListJobs_OmitsFarmerPhones`: phone numbers absent from list response
    - _Requirements: 6.7, 6.8, 16.2, 16.3_

- [ ] 9. Go — route registration in server.go
  - [ ] 9.1 Wire logistics handler, engine, notifier, and scheduler into `agri-chain/server/internal/api/server.go`
    - Instantiate `smsNotifier` using `HUAWEI_SMS_*` env vars from `cfg`
    - Instantiate `aggregationEngine` with default constants
    - Instantiate `LogisticsHandler` via `NewLogisticsHandler(db, engine, notifier)`
    - Register routes following the existing pattern:
      - `logistics.RegisterV1ReadOnly(v1)` — `GET /v1/logistics/jobs` (public, no auth required)
      - Inside `farmer` group (role `farmer`/`admin` + KYC approved): `logistics.RegisterV1Farmer(farmer)` — `POST /v1/logistics/requests`, `GET /v1/logistics/requests/:id`, `DELETE /v1/logistics/requests/:id`
      - Inside `logisticsGroup` (role `logistics`/`admin`): `logistics.RegisterV1Logistics(logisticsGroup)` — `POST /v1/logistics/jobs/:id/accept`, `POST /v1/logistics/jobs/:id/complete`
    - Instantiate `NewScheduler(engine, 15*time.Minute)`, call `scheduler.Start(context.Background())`, and call `scheduler.Stop()` on graceful shutdown
    - _Requirements: 10.5, 17.1, 17.2, 17.3, 17.4_

- [ ] 10. Go — integration tests
  - [ ]* 10.1 Write integration tests in `agri-chain/server/internal/logistics/integration_test.go`
    - Use in-memory SQLite (same pattern as `handlers/contracts_test.go`): open DB, run `db.Migrate()`, run logistics migration
    - `TestTransportRequestLifecycle`: submit request → trigger aggregation with ≥3 requests → verify job created with `status=OPEN` → accept job → verify job `status=ASSIGNED` and all requests `status=ASSIGNED`
    - `TestConcurrentJobAcceptance`: two goroutines accept the same job; verify exactly one gets 200 and the other gets 409
    - `TestCancellationDissolvesJob`: cancel enough requests to drop below `minFarmersToJob`; verify job `status=CANCELLED` and remaining requests revert to `PENDING` with `job_id=NULL`
    - `TestCancellationRecomputesRoute`: cancel one request from a 4-farmer job; verify route is recomputed with 3 stops
    - `TestBackgroundSchedulerPicksUpMissedRequests`: insert 3 PENDING requests without triggering aggregation; call `RunFullAggregation`; verify job is created
    - `TestAggregationDoesNotSplitRequest`: a single request is never split across two jobs
    - _Requirements: 1.1, 1.2, 1.5, 1.7, 1.8, 3.5, 3.6, 6.6, 6.8, 8.2, 10.2_

- [ ] 11. Checkpoint — Go backend
  - Ensure all Go tests pass: `go test ./internal/logistics/...` from `agri-chain/server/`
  - Ensure the server compiles: `go build ./...`
  - Ask the user if any questions arise before proceeding to Flutter.

- [x] 12. Flutter — logistics data models
  - [x] 12.1 Create `agri-chain/lib/features/logistics/models/logistics_models.dart`
    - Implement `TransportRequest` class with all fields from design: `id`, `farmerUid`, `farmerName`, `pickupLat`, `pickupLng`, `pickupParish`, `destinationMarket`, `cropType`, `quantityKg`, `status`, `jobId` (nullable), `createdAt`
    - Implement `AggregatedJob` class with fields: `id`, `destinationMarket`, `originRegion`, `totalQuantityKg`, `farmerCount`, `status`, `route` (nullable `RouteResult`), `centroidLat` (nullable), `centroidLng` (nullable), `createdAt`
    - Implement `RouteResult` class with fields: `orderedStops`, `totalDistanceKm`, `estimatedHours`
    - Implement `RouteStop` class with fields: `stopOrder`, `requestId`, `farmerName`, `parish`, `lat`, `lng`, `quantityKg`
    - Each class must have `fromJson` factory constructor and `toJson` method; use `const` constructors
    - _Requirements: 15.1, 15.2, 15.3, 15.4_
  - [ ]* 12.2 Write unit tests for Dart models in `agri-chain/test/features/logistics/models/logistics_models_test.dart`
    - **Property 5 (Dart): Round-trip consistency** — `fromJson(model.toJson())` produces an equivalent object for `TransportRequest`, `AggregatedJob`, `RouteResult`, `RouteStop`
    - Test nullable fields (`jobId`, `route`, `centroidLat`, `centroidLng`) round-trip correctly when null and when non-null
    - **Validates: Requirements 15.5**

- [x] 13. Flutter — logistics API service
  - [x] 13.1 Create `agri-chain/lib/features/logistics/services/logistics_api_service.dart`
    - Implement `LogisticsApiService` class following the pattern of `contracts_api_service.dart`
    - Implement `submitTransportRequest({required double pickupLat, required double pickupLng, required String pickupParish, String? pickupSubcounty, required String destinationMarket, required String cropType, required double quantityKg, DateTime? harvestReadyAt, String? farmerNotes}) → Future<TransportRequest>`
    - Implement `getRequest({required String requestId}) → Future<TransportRequest>`
    - Implement `cancelRequest({required String requestId}) → Future<void>`
    - Implement `listJobs({String? status, String? market, double? minQuantityKg, int limit = 20, int offset = 0}) → Future<List<AggregatedJob>>`
    - Implement `acceptJob({required String jobId, required String companyId, required double truckCapacityKg, required String driverPhone, DateTime? plannedPickupAt}) → Future<AggregatedJob>`
    - Parse error responses using the `{"error": {"code": ..., "message": ...}}` envelope; throw typed exceptions for `CAPACITY_INSUFFICIENT`, `JOB_ALREADY_ASSIGNED`, `OUTSIDE_UGANDA_BOUNDS`, `REQUEST_NOT_CANCELLABLE`
    - _Requirements: 11.3, 11.4, 12.2, 13.5, 16.1, 16.2, 16.3, 16.4, 16.5_
  - [ ]* 13.2 Write unit tests for `LogisticsApiService` in `agri-chain/test/features/logistics/services/logistics_api_service_test.dart`
    - Use `http.MockClient` to stub API responses
    - Test `submitTransportRequest` parses success response into `TransportRequest`
    - Test `listJobs` with filters passes correct query parameters
    - Test `acceptJob` throws correct exception on `409 JOB_ALREADY_ASSIGNED`
    - Test `submitTransportRequest` throws correct exception on `400 OUTSIDE_UGANDA_BOUNDS`
    - _Requirements: 11.4, 13.5, 16.2, 16.5_

- [x] 14. Flutter — logistics provider
  - [x] 14.1 Create `agri-chain/lib/features/logistics/providers/logistics_provider.dart`
    - Implement `LogisticsProvider extends ChangeNotifier` following the pattern of `blockchain_provider.dart`
    - State fields: `TransportRequest? currentRequest`, `List<AggregatedJob> jobs`, `bool isLoading`, `String? errorMessage`
    - Implement `submitRequest(...)`: call `service.submitTransportRequest`, update `currentRequest`, notify listeners
    - Implement `loadCurrentRequest(String requestId)`: call `service.getRequest`, update `currentRequest`, notify listeners
    - Implement `cancelCurrentRequest()`: call `service.cancelRequest`, clear `currentRequest`, notify listeners
    - Implement `loadJobs({String? status, String? market, double? minQuantityKg})`: call `service.listJobs`, update `jobs`, notify listeners
    - Implement `acceptJob(String jobId, ...)`: call `service.acceptJob`, refresh job in list, notify listeners
    - Expose `LogisticsApiService get service` for direct use in screens
    - _Requirements: 11.3, 11.5, 11.6, 12.2, 12.5, 13.5_
  - [ ]* 14.2 Write unit tests for `LogisticsProvider` in `agri-chain/test/features/logistics/providers/logistics_provider_test.dart`
    - Use a mock `LogisticsApiService`
    - Test `submitRequest` updates `currentRequest` and calls `notifyListeners`
    - Test `loadJobs` populates `jobs` list
    - Test `cancelCurrentRequest` clears `currentRequest`
    - Test error state is set when API throws
    - _Requirements: 11.3, 11.5, 12.2_

- [ ] 15. Flutter — TransportRequestScreen
  - [x] 15.1 Create `agri-chain/lib/features/logistics/screens/transport_request_screen.dart`
    - Implement `TransportRequestScreen` as a `StatefulWidget`
    - Provide a map pin picker using `flutter_map` + `geolocator` for GPS pickup location; populate `pickupLat`, `pickupLng`, `pickupParish` from selected coordinates
    - Provide form fields: destination market (text), crop type (text), quantity in kg (number), optional harvest ready date, optional notes
    - On submit: call `LogisticsProvider.submitRequest(...)`; display returned `status` and `request_id`
    - On API validation error (e.g., `OUTSIDE_UGANDA_BOUNDS`): display inline error on the relevant field without dismissing the form
    - Display current request status (PENDING / AGGREGATED) and update when provider notifies
    - Show cancel button when request is in PENDING or AGGREGATED status; call `LogisticsProvider.cancelCurrentRequest()`
    - _Requirements: 11.1, 11.2, 11.3, 11.4, 11.5, 11.6_
  - [ ]* 15.2 Write widget tests for `TransportRequestScreen` in `agri-chain/test/features/logistics/screens/transport_request_screen_test.dart`
    - Test form validation: submit with empty fields shows error
    - Test inline error display when provider returns `OUTSIDE_UGANDA_BOUNDS`
    - Test cancel button appears when status is PENDING and calls `cancelCurrentRequest`
    - _Requirements: 11.4, 11.6_

- [ ] 16. Flutter — JobBoardScreen
  - [-] 16.1 Create `agri-chain/lib/features/logistics/screens/job_board_screen.dart`
    - Implement `JobBoardScreen` as a `StatefulWidget`
    - On load: call `LogisticsProvider.loadJobs(status: 'OPEN')`; display list with `farmerCount`, `totalQuantityKg`, `destinationMarket`, `originRegion`, `status` per entry
    - Provide filter controls for status, destination market, and minimum quantity; re-call `loadJobs` when filters change
    - Tap on job entry navigates to `JobDetailScreen` passing the job
    - Implement pull-to-refresh using `RefreshIndicator` that calls `loadJobs` again
    - _Requirements: 12.1, 12.2, 12.3, 12.4, 12.5_
  - [ ]* 16.2 Write widget tests for `JobBoardScreen` in `agri-chain/test/features/logistics/screens/job_board_screen_test.dart`
    - Test job list renders `farmerCount` and `totalQuantityKg` for each entry
    - Test filter controls trigger `loadJobs` with correct parameters
    - Test pull-to-refresh calls `loadJobs`
    - _Requirements: 12.1, 12.3, 12.5_

- [ ] 17. Flutter — JobDetailScreen
  - [-] 17.1 Create `agri-chain/lib/features/logistics/screens/job_detail_screen.dart`
    - Implement `JobDetailScreen` as a `StatefulWidget` accepting an `AggregatedJob`
    - Display a `flutter_map` map with markers for each `RouteStop` and a `Polyline` connecting stops in `stop_order` sequence
    - Display a scrollable list of route stops showing `stopOrder`, `farmerName`, `parish`, `lat`, `lng`, `quantityKg`
    - Display `totalDistanceKm` and `estimatedHours`
    - When `job.status == 'OPEN'`: show accept button that opens a bottom sheet / dialog with fields for `truckCapacityKg`, `driverPhone`, `plannedPickupAt`
    - On accept form submit: call `LogisticsProvider.acceptJob(...)`; display result status
    - On `409 JOB_ALREADY_ASSIGNED` response: display "Job already accepted" message and refresh job status
    - When job has > 20 stops: cluster map markers at zoom levels below 12 (use `flutter_map_marker_cluster` or equivalent already in pubspec)
    - _Requirements: 13.1, 13.2, 13.3, 13.4, 13.5, 13.6, 13.7_
  - [ ]* 17.2 Write widget tests for `JobDetailScreen` in `agri-chain/test/features/logistics/screens/job_detail_screen_test.dart`
    - Test stop list renders correct `stopOrder` and `farmerName` for each stop
    - Test accept button is visible when `status == 'OPEN'` and hidden otherwise
    - Test `409` response shows "already accepted" message
    - _Requirements: 13.2, 13.4, 13.6_

- [ ] 18. Final checkpoint — full stack
  - Ensure all Go tests pass: `go test ./...` from `agri-chain/server/`
  - Ensure all Flutter tests pass: `flutter test` from `agri-chain/`
  - Ensure Flutter app compiles: `flutter build apk --debug`
  - Ask the user if any questions arise.

## Notes

- Tasks marked with `*` are optional and can be skipped for a faster MVP; core functionality is fully covered by non-optional tasks.
- Each task references specific requirements for traceability.
- Go backend tasks (1–11) must be completed before Flutter tasks (12–18) because Flutter depends on the API contract.
- The `LogisticsHandler` exposes three route-registration methods (`RegisterV1ReadOnly`, `RegisterV1Farmer`, `RegisterV1Logistics`) following the existing `ContractsHandler` pattern in `server.go`.
- All DB writes in the aggregation engine and job acceptance handler use a single SQLite transaction; the existing `SetMaxOpenConns(1)` + WAL mode ensures serialised writes without explicit locking.
- Property-based tests use Go's `testing/quick` stdlib package (already available); no new test dependencies are needed.
- Flutter tests use `flutter_test` and `mockito` (or `mocktail`) following the existing test pattern.

## Task Dependency Graph

```json
{
  "waves": [
    { "id": 0, "tasks": ["1.1"] },
    { "id": 1, "tasks": ["2.1"] },
    { "id": 2, "tasks": ["2.2", "3.1"] },
    { "id": 3, "tasks": ["3.2", "3.3"] },
    { "id": 4, "tasks": ["3.4", "4.1"] },
    { "id": 5, "tasks": ["4.2", "4.3", "5.1"] },
    { "id": 6, "tasks": ["5.2", "6.1"] },
    { "id": 7, "tasks": ["6.2", "7.1"] },
    { "id": 8, "tasks": ["7.2"] },
    { "id": 9, "tasks": ["7.3", "8.1"] },
    { "id": 10, "tasks": ["7.4", "8.2"] },
    { "id": 11, "tasks": ["8.3"] },
    { "id": 12, "tasks": ["8.4", "9.1"] },
    { "id": 13, "tasks": ["10.1"] },
    { "id": 14, "tasks": ["12.1"] },
    { "id": 15, "tasks": ["12.2", "13.1"] },
    { "id": 16, "tasks": ["13.2", "14.1"] },
    { "id": 17, "tasks": ["14.2", "15.1"] },
    { "id": 18, "tasks": ["15.2", "16.1"] },
    { "id": 19, "tasks": ["16.2", "17.1"] },
    { "id": 20, "tasks": ["17.2"] }
  ]
}
```
