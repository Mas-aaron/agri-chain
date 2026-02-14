package sqlite

import (
	"context"
	"database/sql"
	"errors"
	"fmt"
	"os"
	"path/filepath"
	"time"

	_ "modernc.org/sqlite"
)

type DB struct {
	sql *sql.DB
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
	stmts := []string{
		`PRAGMA journal_mode=WAL;`,
		`PRAGMA foreign_keys=ON;`,
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

func (d *DB) GetKYCStatus(ctx context.Context, uid string) (string, error) {
	var status string
	err := d.sql.QueryRowContext(ctx, `SELECT kyc_status FROM users WHERE uid = ?`, uid).Scan(&status)
	if errors.Is(err, sql.ErrNoRows) {
		return "pending", nil
	}
	return status, err
}
