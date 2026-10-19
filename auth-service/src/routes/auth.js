'use strict';

const fs = require('fs');
const express = require('express');
const bcrypt = require('bcryptjs');
const jwt = require('jsonwebtoken');

const { pool } = require('../db');

const router = express.Router();

const JWT_ISSUER = process.env.JWT_ISSUER || 'auth-service';
const JWT_TTL = process.env.JWT_TTL || '1h';
const PRIVATE_KEY_PATH = process.env.PRIVATE_KEY_PATH || '/keys/jwtRS256.key';

// Read the RS256 private key once at startup. The key is mounted at runtime
// (never baked into the image). Failing fast here surfaces a misconfigured
// mount immediately instead of at first login.
const privateKey = fs.readFileSync(PRIVATE_KEY_PATH, 'utf8');

// POST /auth/login — verify credentials and return a signed RS256 JWT.
// The `iss` claim equals JWT_ISSUER ('auth-service'); Kong's jwt plugin
// matches this against the credential `key` to resolve the consumer.
router.post('/login', async (req, res) => {
  const { username, password } = req.body || {};
  if (!username || !password) {
    return res.status(400).json({ error: 'username and password are required' });
  }

  try {
    const result = await pool.query(
      'SELECT id, username, password_hash FROM users WHERE username = $1',
      [username]
    );

    if (result.rowCount === 0) {
      return res.status(401).json({ error: 'invalid credentials' });
    }

    const user = result.rows[0];
    const ok = await bcrypt.compare(password, user.password_hash);
    if (!ok) {
      return res.status(401).json({ error: 'invalid credentials' });
    }

    const token = jwt.sign(
      { sub: String(user.id), username: user.username },
      privateKey,
      {
        algorithm: 'RS256',
        issuer: JWT_ISSUER,
        expiresIn: JWT_TTL,
      }
    );

    return res.json({ token });
  } catch (err) {
    console.error('login error:', err);
    return res.status(500).json({ error: 'internal error' });
  }
});

// POST /auth/register — create a new user with a bcrypt-hashed password.
router.post('/register', async (req, res) => {
  const { username, password, email } = req.body || {};
  if (!username || !password) {
    return res.status(400).json({ error: 'username and password are required' });
  }

  try {
    const passwordHash = await bcrypt.hash(password, 10);
    const result = await pool.query(
      'INSERT INTO users (username, email, password_hash) VALUES ($1, $2, $3) RETURNING id, username, email',
      [username, email || null, passwordHash]
    );

    return res.status(201).json({ user: result.rows[0] });
  } catch (err) {
    // 23505 = unique_violation (duplicate username).
    if (err && err.code === '23505') {
      return res.status(409).json({ error: 'username already exists' });
    }
    console.error('register error:', err);
    return res.status(500).json({ error: 'internal error' });
  }
});

module.exports = router;
