package sqlite

import (
	"context"
	"database/sql"
	"errors"
	"fmt"
	"os"
	"path/filepath"
	"strings"
	"time"

	_ "modernc.org/sqlite"
)

type DB struct {
	sql *sql.DB
}

type UserSummary struct {
	UID       string   `json:"uid"`
	Email     string   `json:"email"`
	KYCStatus string   `json:"kyc_status"`
	Roles     []string `json:"roles"`
}

func (d *DB) SQL() *sql.DB {
	return d.sql
}

func Open(path string) (*DB, error) {
	if path == "" {
		return nil, errors.New("sqlite path is empty")
	}
	if err := os.MkdirAll(filepath.Dir(path), 0o755); err != nil {
		return nil, err
	}
	db, err := sql.Open("sqlite", path)
	if err != nil {
		return nil, err
	}
	db.SetMaxOpenConns(1)
	db.SetConnMaxLifetime(30 * time.Minute)
	return &DB{sql: db}, nil
}

func (d *DB) Close() error {
	return d.sql.Close()
}

func (d *DB) Migrate(ctx context.Context) error {
	// NOTE: PRAGMA journal_mode cannot be changed inside a transaction.
	// Run PRAGMAs first, then apply DDL within a transaction.
	pragmas := []string{
		`PRAGMA journal_mode=WAL;`,
		`PRAGMA foreign_keys=ON;`,
		`PRAGMA busy_timeout=5000;`,
	}
	for i, p := range pragmas {
		if _, err := d.sql.ExecContext(ctx, p); err != nil {
			return fmt.Errorf("pragma %d failed: %w", i, err)
		}
	}

	stmts := []string{
		`CREATE TABLE IF NOT EXISTS users (
			uid TEXT PRIMARY KEY,
			email TEXT,
			kyc_status TEXT NOT NULL DEFAULT 'pending',
			created_at TEXT NOT NULL,
			updated_at TEXT NOT NULL
		);`,
		`CREATE TABLE IF NOT EXISTS user_roles (
			uid TEXT NOT NULL,
			role TEXT NOT NULL,
			created_at TEXT NOT NULL,
			PRIMARY KEY (uid, role),
			FOREIGN KEY(uid) REFERENCES users(uid) ON DELETE CASCADE
		);`,
		`CREATE TABLE IF NOT EXISTS device_tokens (
			uid TEXT NOT NULL,
			token TEXT NOT NULL,
			platform TEXT,
			created_at TEXT NOT NULL,
			PRIMARY KEY (uid, token),
			FOREIGN KEY(uid) REFERENCES users(uid) ON DELETE CASCADE
		);`,
		`CREATE TABLE IF NOT EXISTS contracts (
			id TEXT PRIMARY KEY,
			crop TEXT NOT NULL,
			quantity_kg REAL NOT NULL,
			unit_price REAL NOT NULL,
			currency TEXT NOT NULL,
			status TEXT NOT NULL,
			farmer_name TEXT NOT NULL,
			buyer_name TEXT,
			evidence_hash TEXT,
			created_at TEXT NOT NULL,
			updated_at TEXT NOT NULL
		);`,
		`CREATE TABLE IF NOT EXISTS ledger_events (
			id TEXT PRIMARY KEY,
			time TEXT NOT NULL,
			action TEXT NOT NULL,
			actor TEXT NOT NULL,
			contract_id TEXT NOT NULL,
			meta_json TEXT NOT NULL
		);`,
		`CREATE INDEX IF NOT EXISTS idx_ledger_contract_id ON ledger_events (contract_id);`,

		// ── Logistics Aggregation Module ──────────────────────────────────────
		// aggregated_jobs must be created before transport_requests (FK dependency)
		`CREATE TABLE IF NOT EXISTS aggregated_jobs (
			id                 TEXT PRIMARY KEY,
			destination_market TEXT NOT NULL,
			origin_region      TEXT NOT NULL,
			total_quantity_kg  REAL NOT NULL,
			farmer_count       INTEGER NOT NULL,
			status             TEXT NOT NULL DEFAULT 'OPEN',
			route_json         TEXT,
			centroid_lat       REAL,
			centroid_lng       REAL,
			created_at         TEXT NOT NULL,
			updated_at         TEXT NOT NULL
		);`,
		`CREATE TABLE IF NOT EXISTS transport_requests (
			id               TEXT PRIMARY KEY,
			farmer_uid       TEXT NOT NULL,
			farmer_name      TEXT NOT NULL,
			farmer_phone     TEXT,
			pickup_lat       REAL NOT NULL,
			pickup_lng       REAL NOT NULL,
			pickup_parish    TEXT NOT NULL,
			pickup_subcounty TEXT,
			destination_market TEXT NOT NULL,
			crop_type        TEXT NOT NULL,
			quantity_kg      REAL NOT NULL CHECK(quantity_kg > 0),
			harvest_ready_at TEXT,
			farmer_notes     TEXT,
			status           TEXT NOT NULL DEFAULT 'PENDING',
			job_id           TEXT,
			created_at       TEXT NOT NULL,
			updated_at       TEXT NOT NULL,
			FOREIGN KEY(farmer_uid) REFERENCES users(uid) ON DELETE CASCADE,
			FOREIGN KEY(job_id) REFERENCES aggregated_jobs(id) ON DELETE SET NULL
		);`,
		`CREATE TABLE IF NOT EXISTS job_requests (
			job_id     TEXT NOT NULL,
			request_id TEXT NOT NULL,
			added_at   TEXT NOT NULL,
			PRIMARY KEY (job_id, request_id),
			FOREIGN KEY(job_id) REFERENCES aggregated_jobs(id) ON DELETE CASCADE,
			FOREIGN KEY(request_id) REFERENCES transport_requests(id) ON DELETE CASCADE
		);`,
		`CREATE TABLE IF NOT EXISTS job_assignments (
			id               TEXT PRIMARY KEY,
			job_id           TEXT NOT NULL,
			company_id       TEXT NOT NULL,
			driver_phone     TEXT NOT NULL,
			truck_capacity_kg REAL NOT NULL,
			planned_pickup_at TEXT,
			accepted_at      TEXT NOT NULL,
			status           TEXT NOT NULL DEFAULT 'ACTIVE',
			FOREIGN KEY(job_id) REFERENCES aggregated_jobs(id)
		);`,
		`CREATE INDEX IF NOT EXISTS idx_transport_requests_status      ON transport_requests(status);`,
		`CREATE INDEX IF NOT EXISTS idx_transport_requests_destination  ON transport_requests(destination_market);`,
		`CREATE INDEX IF NOT EXISTS idx_transport_requests_farmer       ON transport_requests(farmer_uid);`,
		`CREATE INDEX IF NOT EXISTS idx_transport_requests_job          ON transport_requests(job_id);`,
		`CREATE INDEX IF NOT EXISTS idx_aggregated_jobs_status          ON aggregated_jobs(status);`,
		`CREATE INDEX IF NOT EXISTS idx_aggregated_jobs_destination     ON aggregated_jobs(destination_market);`,
		`CREATE INDEX IF NOT EXISTS idx_job_requests_request            ON job_requests(request_id);`,
	}

	tx, err := d.sql.BeginTx(ctx, nil)
	if err != nil {
		return err
	}
	defer func() { _ = tx.Rollback() }()

	for i, stmt := range stmts {
		if _, err := tx.ExecContext(ctx, stmt); err != nil {
			return fmt.Errorf("migration %d failed: %w", i, err)
		}
	}
	return tx.Commit()
}

func (d *DB) EnsureUser(ctx context.Context, uid string, email string) error {
	now := time.Now().UTC().Format(time.RFC3339Nano)
	_, err := d.sql.ExecContext(ctx, `INSERT INTO users(uid, email, created_at, updated_at) VALUES(?,?,?,?)
		ON CONFLICT(uid) DO UPDATE SET email=excluded.email, updated_at=excluded.updated_at`, uid, email, now, now)
	return err
}

func (d *DB) GetUserRoles(ctx context.Context, uid string) ([]string, error) {
	rows, err := d.sql.QueryContext(ctx, `SELECT role FROM user_roles WHERE uid = ? ORDER BY role`, uid)
	if err != nil {
		return nil, err
	}
	defer rows.Close()
	var roles []string
	for rows.Next() {
		var r string
		if err := rows.Scan(&r); err != nil {
			return nil, err
		}
		roles = append(roles, r)
	}
	if err := rows.Err(); err != nil {
		return nil, err
	}
	return roles, nil
}

func (d *DB) ReplaceUserRoles(ctx context.Context, uid string, roles []string) error {
	now := time.Now().UTC().Format(time.RFC3339Nano)

	tx, err := d.sql.BeginTx(ctx, nil)
	if err != nil {
		return err
	}
	defer func() { _ = tx.Rollback() }()

	// Ensure user row exists so the FK constraint doesn't fail.
	_, err = tx.ExecContext(ctx, `INSERT INTO users(uid, created_at, updated_at) VALUES(?,?,?)
		ON CONFLICT(uid) DO UPDATE SET updated_at=excluded.updated_at`, uid, now, now)
	if err != nil {
		return err
	}

	if _, err := tx.ExecContext(ctx, `DELETE FROM user_roles WHERE uid = ?`, uid); err != nil {
		return err
	}

	for _, r := range roles {
		r = strings.TrimSpace(r)
		if r == "" {
			continue
		}
		if _, err := tx.ExecContext(ctx, `INSERT INTO user_roles(uid, role, created_at) VALUES(?,?,?)`, uid, r, now); err != nil {
			return err
		}
	}

	return tx.Commit()
}

func (d *DB) GetKYCStatus(ctx context.Context, uid string) (string, error) {
	var status string
	err := d.sql.QueryRowContext(ctx, `SELECT kyc_status FROM users WHERE uid = ?`, uid).Scan(&status)
	if errors.Is(err, sql.ErrNoRows) {
		return "pending", nil
	}
	return status, err
}

func (d *DB) SetKYCStatus(ctx context.Context, uid string, status string) error {
	status = strings.TrimSpace(status)
	if status == "" {
		return errors.New("kyc status is empty")
	}
	now := time.Now().UTC().Format(time.RFC3339Nano)
	_, err := d.sql.ExecContext(ctx, `INSERT INTO users(uid, kyc_status, created_at, updated_at) VALUES(?,?,?,?)
		ON CONFLICT(uid) DO UPDATE SET kyc_status=excluded.kyc_status, updated_at=excluded.updated_at`, uid, status, now, now)
	return err
}

func (d *DB) UpsertDeviceToken(ctx context.Context, uid string, token string, platform string) error {
	token = strings.TrimSpace(token)
	platform = strings.TrimSpace(platform)
	if token == "" {
		return errors.New("device token is empty")
	}
	now := time.Now().UTC().Format(time.RFC3339Nano)
	// Ensure user row exists so the FK constraint doesn't fail.
	_, _ = d.sql.ExecContext(ctx, `INSERT INTO users(uid, created_at, updated_at) VALUES(?,?,?)
		ON CONFLICT(uid) DO UPDATE SET updated_at=excluded.updated_at`, uid, now, now)

	_, err := d.sql.ExecContext(ctx, `INSERT INTO device_tokens(uid, token, platform, created_at) VALUES(?,?,?,?)
		ON CONFLICT(uid, token) DO UPDATE SET platform=excluded.platform, created_at=excluded.created_at`, uid, token, platform, now)
	return err
}

func (d *DB) ListDeviceTokens(ctx context.Context, uid string) ([]string, error) {
	rows, err := d.sql.QueryContext(ctx, `SELECT token FROM device_tokens WHERE uid = ? ORDER BY created_at DESC`, uid)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	var out []string
	for rows.Next() {
		var t string
		if err := rows.Scan(&t); err != nil {
			return nil, err
		}
		out = append(out, t)
	}
	if err := rows.Err(); err != nil {
		return nil, err
	}
	return out, nil
}

func (d *DB) ListUsers(ctx context.Context, limit int) ([]UserSummary, error) {
	if limit <= 0 {
		limit = 200
	}
	rows, err := d.sql.QueryContext(ctx, `
		SELECT u.uid, COALESCE(u.email,''), COALESCE(u.kyc_status,'pending'), COALESCE(r.role,'')
		FROM users u
		LEFT JOIN user_roles r ON r.uid = u.uid
		ORDER BY u.updated_at DESC
		LIMIT ?`, limit)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	byUID := map[string]*UserSummary{}
	order := []string{}
	for rows.Next() {
		var uid, email, kyc, role string
		if err := rows.Scan(&uid, &email, &kyc, &role); err != nil {
			return nil, err
		}
		u, ok := byUID[uid]
		if !ok {
			u = &UserSummary{UID: uid, Email: email, KYCStatus: kyc, Roles: []string{}}
			byUID[uid] = u
			order = append(order, uid)
		}
		if role != "" {
			u.Roles = append(u.Roles, role)
		}
	}
	if err := rows.Err(); err != nil {
		return nil, err
	}

	out := make([]UserSummary, 0, len(order))
	for _, uid := range order {
		out = append(out, *byUID[uid])
	}
	return out, nil
}
