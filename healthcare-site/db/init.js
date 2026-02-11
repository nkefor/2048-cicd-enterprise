const Database = require('better-sqlite3');
const fs = require('fs');
const path = require('path');
const bcrypt = require('bcryptjs');

const DB_PATH = process.env.DB_PATH || path.join(__dirname, 'practice.db');

function initDatabase() {
    const db = new Database(DB_PATH);

    // Enable WAL mode for better concurrent access
    db.pragma('journal_mode = WAL');
    db.pragma('foreign_keys = ON');

    // Read and execute schema
    const schema = fs.readFileSync(path.join(__dirname, 'schema.sql'), 'utf8');
    db.exec(schema);

    // Create default admin user if none exists
    const adminExists = db.prepare('SELECT COUNT(*) as count FROM admin_users').get();
    if (adminExists.count === 0) {
        const passwordHash = bcrypt.hashSync('changeme123', 12);
        db.prepare(`
            INSERT INTO admin_users (username, email, password_hash, role, first_name, last_name, credentials)
            VALUES (?, ?, ?, ?, ?, ?, ?)
        `).run('admin', 'admin@yourpractice.com', passwordHash, 'provider', 'Provider', 'Admin', 'NP-C');
        console.log('Default admin user created (username: admin, password: changeme123)');
    }

    console.log('Database initialized successfully at:', DB_PATH);
    db.close();
}

if (require.main === module) {
    require('dotenv').config({ path: path.join(__dirname, '..', '.env') });
    initDatabase();
}

module.exports = { initDatabase, DB_PATH };
