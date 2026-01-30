const sqlite3 = require('sqlite3').verbose();
const path = require('path');
const fs = require('fs');

const dbPath = path.resolve(process.env.DATABASE_URL || './data/agritech.db');
const dbDir = path.dirname(dbPath);

// Ensure database directory exists
if (!fs.existsSync(dbDir)) {
  fs.mkdirSync(dbDir, { recursive: true });
}

const db = new sqlite3.Database(dbPath, (err) => {
  if (err) {
    console.error('Error opening database:', err);
  } else {
    console.log('Connected to SQLite database at:', dbPath);
    initializeTables();
  }
});

/**
 * Initialize database tables
 */
function initializeTables() {
  // Farmers table
  db.run(`
    CREATE TABLE IF NOT EXISTS farmers (
      id TEXT PRIMARY KEY,
      wallet_address TEXT UNIQUE NOT NULL,
      private_key_encrypted TEXT NOT NULL,
      name TEXT NOT NULL,
      email TEXT UNIQUE,
      phone TEXT,
      kyc_status TEXT DEFAULT 'pending',
      kyc_verification_date DATETIME,
      farm_location TEXT,
      farm_size_hectares REAL,
      crop_type TEXT,
      created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
      updated_at DATETIME DEFAULT CURRENT_TIMESTAMP
    )
  `);

  // Yield tokens table
  db.run(`
    CREATE TABLE IF NOT EXISTS yield_tokens (
      id TEXT PRIMARY KEY,
      token_id INTEGER NOT NULL,
      farmer_id TEXT NOT NULL,
      farm_id TEXT NOT NULL,
      crop_type TEXT NOT NULL,
      season TEXT NOT NULL,
      predicted_yield REAL NOT NULL,
      confidence_score REAL NOT NULL,
      actual_yield REAL,
      ipfs_hash TEXT,
      transaction_hash TEXT,
      token_status TEXT DEFAULT 'minted',
      minted_at DATETIME DEFAULT CURRENT_TIMESTAMP,
      harvested_at DATETIME,
      created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
      updated_at DATETIME DEFAULT CURRENT_TIMESTAMP,
      FOREIGN KEY (farmer_id) REFERENCES farmers(id)
    )
  `);

  // Loans table
  db.run(`
    CREATE TABLE IF NOT EXISTS loans (
      id TEXT PRIMARY KEY,
      farmer_id TEXT NOT NULL,
      token_id INTEGER NOT NULL,
      principal_amount REAL NOT NULL,
      interest_rate REAL NOT NULL,
      total_repayment REAL NOT NULL,
      ltv_ratio REAL NOT NULL,
      due_date DATETIME NOT NULL,
      repaid_amount REAL DEFAULT 0,
      status TEXT DEFAULT 'active',
      transaction_hash TEXT,
      created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
      repaid_at DATETIME,
      liquidated_at DATETIME,
      FOREIGN KEY (farmer_id) REFERENCES farmers(id)
    )
  `);

  // Oracle updates table
  db.run(`
    CREATE TABLE IF NOT EXISTS oracle_updates (
      id TEXT PRIMARY KEY,
      token_id INTEGER NOT NULL,
      actual_yield REAL NOT NULL,
      oracle_signature TEXT,
      source TEXT,
      accuracy_percentage REAL,
      transaction_hash TEXT,
      processed_at DATETIME DEFAULT CURRENT_TIMESTAMP,
      created_at DATETIME DEFAULT CURRENT_TIMESTAMP
    )
  `);

  // Transaction history table
  db.run(`
    CREATE TABLE IF NOT EXISTS transactions (
      id TEXT PRIMARY KEY,
      farmer_id TEXT,
      transaction_type TEXT NOT NULL,
      transaction_hash TEXT UNIQUE,
      contract_name TEXT,
      function_name TEXT,
      parameters TEXT,
      status TEXT DEFAULT 'pending',
      gas_used REAL,
      cost_eth REAL,
      error_message TEXT,
      created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
      confirmed_at DATETIME,
      FOREIGN KEY (farmer_id) REFERENCES farmers(id)
    )
  `);

  // Wallet backup logs table
  db.run(`
    CREATE TABLE IF NOT EXISTS wallet_backups (
      id TEXT PRIMARY KEY,
      farmer_id TEXT NOT NULL,
      backup_path TEXT NOT NULL,
      encrypted BOOLEAN DEFAULT 1,
      created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
      FOREIGN KEY (farmer_id) REFERENCES farmers(id)
    )
  `);

  console.log('Database tables initialized');
}

/**
 * Database utility functions
 */
const DatabaseService = {
  /**
   * Run a single query
   */
  run: (query, params = []) => {
    return new Promise((resolve, reject) => {
      db.run(query, params, function(err) {
        if (err) reject(err);
        else resolve({ id: this.lastID, changes: this.changes });
      });
    });
  },

  /**
   * Get a single row
   */
  get: (query, params = []) => {
    return new Promise((resolve, reject) => {
      db.get(query, params, (err, row) => {
        if (err) reject(err);
        else resolve(row);
      });
    });
  },

  /**
   * Get all rows
   */
  all: (query, params = []) => {
    return new Promise((resolve, reject) => {
      db.all(query, params, (err, rows) => {
        if (err) reject(err);
        else resolve(rows || []);
      });
    });
  },

  /**
   * Close database connection
   */
  close: () => {
    return new Promise((resolve, reject) => {
      db.close((err) => {
        if (err) reject(err);
        else resolve();
      });
    });
  }
};

module.exports = DatabaseService;
