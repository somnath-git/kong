'use strict';

// Postgres connection pool for the application database (users table).
// All connection settings come from environment variables so the same image
// runs unchanged across local/compose and other environments.
const { Pool } = require('pg');

const pool = new Pool({
  host: process.env.DB_HOST || 'app-database',
  port: parseInt(process.env.DB_PORT || '5432', 10),
  user: process.env.DB_USER,
  password: process.env.DB_PASSWORD,
  database: process.env.DB_NAME,
});

module.exports = { pool };
