-- 01-schema.sql — application database schema for the Kong JWT auth scaffold.
-- Runs automatically on first start of the app-database (postgres docker-entrypoint-initdb.d).
--
-- DEV-ONLY: this file seeds a demo user with a known password for local
-- development and learning only. NEVER ship this seed (or the known password)
-- to any real or production environment.

CREATE TABLE IF NOT EXISTS users (
    id            SERIAL PRIMARY KEY,
    username      TEXT UNIQUE NOT NULL,
    email         TEXT,
    password_hash TEXT NOT NULL,
    created_at    TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- DEV-ONLY seed user.
--   username: demo
--   password: demopass  (plaintext, DEV-ONLY — do not reuse anywhere real)
-- password_hash is a bcryptjs $2b$ hash of 'demopass' at cost 10, generated with
-- the same bcryptjs library the auth service uses so compareSync() matches.
INSERT INTO users (username, email, password_hash)
VALUES (
    'demo',
    'demo@example.com',
    '$2b$10$O01JNDiB0TFTNrBA.Jo06O3PXtJhdAq8eO832cCeM.hZo8iBbmpNy'
)
ON CONFLICT (username) DO NOTHING;
