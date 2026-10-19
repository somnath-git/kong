'use strict';

const express = require('express');

const { pool } = require('./db');
const authRoutes = require('./routes/auth');

const app = express();
app.use(express.json());

app.use('/auth', authRoutes);

// GET /health — liveness/readiness probe. Confirms the DB is reachable.
app.get('/health', async (req, res) => {
  try {
    await pool.query('SELECT 1');
    return res.status(200).json({ status: 'ok' });
  } catch (err) {
    console.error('health check failed:', err);
    return res.status(503).json({ status: 'error' });
  }
});

const port = parseInt(process.env.PORT || '3000', 10);
app.listen(port, () => {
  console.log(`auth-service listening on port ${port}`);
});
