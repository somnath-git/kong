# Kong JWT Auth Scaffold

A small, self-contained learning stack that shows how to put **Kong Gateway** in
front of an API and enforce **RS256 JWT** authentication. A Node/Express auth
service signs tokens; Kong's `jwt` plugin verifies them before proxying to a
protected upstream.

Everything comes up with a single `docker compose up`.

> **DEV-ONLY.** Every password and the committed RS256 keypair in this repo are
> for local learning only. Do **not** reuse them anywhere real. See
> [DEV-ONLY warnings](#dev-only-warnings).

---

## Architecture

The stack is seven containers on one Docker network. Kong runs in **DB mode**,
so it stores its own configuration in a dedicated Postgres instance. A second,
separate Postgres instance holds the application's `users` table.

```
                                 Docker network: kong-net
  ┌─────────┐
  │ client  │  (your host: curl / PowerShell)
  └────┬────┘
       │  http://localhost:8000
       ▼
  ┌──────────────────────────── Kong Gateway (kong:3.6) ────────────────────────────┐
  │  proxy :8000   admin :8001   https :8443                                         │
  │                                                                                  │
  │   Route /auth  (strip_path=false, NO auth)         Route /api  (jwt + rate-limit)│
  └───────┬──────────────────────────────────────────────────┬──────────────────────┘
          │                                                   │  verify RS256 JWT
          │                                                   │  (iss must = "auth-service")
          ▼                                                   ▼
   ┌──────────────┐                                    ┌──────────────┐
   │ auth-service │  signs RS256 JWT                   │   httpbin    │  protected upstream
   │  :3000       │  (private key)                     │   :8080      │  (go-httpbin)
   └──────┬───────┘                                    └──────────────┘
          │ reads/writes users
          ▼
   ┌──────────────┐        ┌──────────────┐
   │ app-database │        │ kong-database│  Kong's own config
   │ (users)      │        │ (services,   │  (services/routes/
   │ host :5433   │        │  routes…)    │   plugins/consumers)
   └──────────────┘        └──────────────┘

   one-shot helpers (run once, then exit 0):
     kong-migrations  — creates Kong's schema in kong-database
     kong-bootstrap   — configures Kong's services/routes/plugins/consumer via the Admin API
```

### Request flow

1. **Login (unprotected).** The client calls `POST http://localhost:8000/auth/login`.
   Kong matches the `/auth` route, applies **no** auth plugin, and proxies to
   `auth-service`. The service checks the password (bcrypt) and returns a signed
   **RS256 JWT** whose `iss` claim is `auth-service`.
2. **Call protected API without a token.** `GET http://localhost:8000/api/get`
   matches the `/api` route, where Kong's `jwt` plugin runs. With no token, Kong
   returns **401** and never reaches the upstream.
3. **Call protected API with the token.** The same request with
   `Authorization: Bearer <token>` passes the `jwt` plugin. Kong looks up the
   credential by the token's `iss` (`auth-service`), verifies the RS256 signature
   against the stored public key, and proxies to `httpbin`, returning **200**.
4. **Register.** `POST http://localhost:8000/auth/register` goes through the
   unprotected `/auth` route to the auth service, which creates a new user.

---

## The two Postgres instances

This trips people up, so it is worth stating plainly: there are **two completely
separate** Postgres databases, and they do not share data.

| Instance        | Image              | Holds                                                         | Who uses it        | Host port |
| --------------- | ------------------ | ------------------------------------------------------------- | ------------------ | --------- |
| `kong-database` | `postgres:16-alpine` | **Kong's own configuration** — services, routes, plugins, consumers, credentials | Kong Gateway       | (internal only) |
| `app-database`  | `postgres:16-alpine` | **The application `users` table** — usernames + bcrypt password hashes | `auth-service`     | `5433`    |

- `kong-database` is an implementation detail of running Kong in **DB mode**.
  You rarely touch it directly; Kong reads and writes it for you. It is **not**
  published to the host.
- `app-database` is *your* data — the user accounts the auth service
  authenticates against. It is published on host port **5433** so you can inspect
  it locally without clashing with anything on 5432.

They are intentionally isolated. Kong's config DB knows nothing about your users;
your app DB knows nothing about Kong's routes.

---

## Prerequisites

- **Docker Desktop** on Windows (Docker Engine 20.10+, Compose v2). Compose v2 is
  invoked as `docker compose` (a space, not the old `docker-compose`).
- Ports **8000, 8001, 8443, 3000, 5433** free on your host.

No local Node, Postgres, or OpenSSL install is needed — everything runs in
containers.

---

## Startup

From the workspace root:

```bash
docker compose up
```

The **first run** does more work:

- builds the `auth-service` image,
- runs `kong-migrations` to create Kong's schema in `kong-database`,
- runs `kong-bootstrap` to configure Kong (services, routes, the `jwt` plugin,
  the `app-users` consumer + RS256 credential, and `rate-limiting`),
- initializes `app-database` from `db/init/01-schema.sql` (creates the `users`
  table and seeds the `demo` user).

`kong-migrations` and `kong-bootstrap` are one-shot containers: they run, print a
success line, and **exit 0**. That is expected — they are not long-running
services.

Bring it up detached and watch status with:

```bash
docker compose up -d
docker compose ps -a
```

Healthy state looks like: `kong`, `kong-database`, `app-database`, `auth-service`,
`httpbin` up/healthy, and `kong-migrations` + `kong-bootstrap` **Exited (0)**.

To stop and remove everything (including the DB volumes):

```bash
docker compose down -v
```

---

## Ports

| Service        | Container port | Host port | Purpose                                        |
| -------------- | -------------- | --------- | ---------------------------------------------- |
| `kong`         | 8000           | **8000**  | Kong **proxy** — send all API traffic here     |
| `kong`         | 8001           | **8001**  | Kong **Admin API** — inspect/manage config     |
| `kong`         | 8443           | **8443**  | Kong proxy over TLS                            |
| `auth-service` | 3000           | **3000**  | Auth service (also reachable directly for debugging) |
| `app-database` | 5432           | **5433**  | Application Postgres (users table)             |
| `kong-database`| 5432           | —         | Kong's config Postgres (internal only, not published) |

All application traffic should go through the Kong proxy on **8000**. The
`auth-service` on 3000 is exposed only for convenience while learning.

---

## Seed credentials (DEV-ONLY)

The app database is seeded with one user so you can log in immediately:

| Username | Password   |
| -------- | ---------- |
| `demo`   | `demopass` |

> **DEV-ONLY.** This account exists only for local testing. Never ship it.

---

## Example flows

Four flows against the Kong proxy on `http://localhost:8000`, each in **curl**
and **PowerShell** (`Invoke-RestMethod`).

> Because the `/api` route strips its path prefix, `GET /api/get` reaches
> `httpbin`'s `/get` endpoint.

### 1. Login — get a JWT

**curl**

```bash
curl -s -X POST http://localhost:8000/auth/login \
  -H "Content-Type: application/json" \
  -d '{"username":"demo","password":"demopass"}'
```

**PowerShell**

```powershell
$login = Invoke-RestMethod -Method Post -Uri "http://localhost:8000/auth/login" `
  -ContentType "application/json" `
  -Body '{"username":"demo","password":"demopass"}'
$token = $login.token
$token
```

Returns `{"token":"<JWT>"}`. The token's header has `alg=RS256` and its payload
has `iss=auth-service`.

### 2. Call the protected API with no token → 401

**curl**

```bash
curl -i http://localhost:8000/api/get
```

**PowerShell**

```powershell
try {
  Invoke-RestMethod -Uri "http://localhost:8000/api/get"
} catch {
  $_.Exception.Response.StatusCode.value__   # 401
}
```

Kong's `jwt` plugin rejects the request with **401 Unauthorized** before it ever
reaches `httpbin`.

### 3. Call the protected API with the Bearer token → 200

**curl**

```bash
TOKEN=$(curl -s -X POST http://localhost:8000/auth/login \
  -H "Content-Type: application/json" \
  -d '{"username":"demo","password":"demopass"}' | sed 's/.*"token":"\([^"]*\)".*/\1/')

curl -s http://localhost:8000/api/get \
  -H "Authorization: Bearer $TOKEN"
```

**PowerShell**

```powershell
$login = Invoke-RestMethod -Method Post -Uri "http://localhost:8000/auth/login" `
  -ContentType "application/json" `
  -Body '{"username":"demo","password":"demopass"}'

Invoke-RestMethod -Uri "http://localhost:8000/api/get" `
  -Headers @{ Authorization = "Bearer $($login.token)" }
```

Returns **200** with httpbin's JSON (the headers it received, etc.).

### 4. Register a new user

**curl**

```bash
curl -s -X POST http://localhost:8000/auth/register \
  -H "Content-Type: application/json" \
  -d '{"username":"alice","password":"alicepass","email":"alice@example.com"}'
```

**PowerShell**

```powershell
Invoke-RestMethod -Method Post -Uri "http://localhost:8000/auth/register" `
  -ContentType "application/json" `
  -Body '{"username":"alice","password":"alicepass","email":"alice@example.com"}'
```

Returns **201** with the created user (`{"user":{...}}`). A duplicate username
returns **409**. The new user can then log in via flow 1.

> The `/api` route also has a `rate-limiting` plugin (5 requests/minute). If you
> loop flow 3 quickly you will start seeing **429 Too Many Requests** — that is
> expected.

---

## RS256 failure modes

When the protected route returns 401 even with a token, it is almost always one
of these. The `jwt` plugin verifies the signature against a public key it looked
up by the token's issuer, so every piece has to line up:

- **`iss` must equal the credential `key`.** The JWT's `iss` claim is
  `auth-service`, and Kong's credential `key` is also `auth-service`. Kong uses
  `iss` to find which consumer/credential (and therefore which public key) to
  verify against. If they differ, Kong can't find the key and rejects the token.
- **`rsa_public_key` PEM newline formatting.** The public key must be stored in
  Kong as a real multi-line PEM (literal newlines), not a single line with `\n`
  escapes. The bootstrap posts it with
  `curl --data-urlencode "rsa_public_key@/keys/jwtRS256.key.pub"` precisely so the
  file's real newlines are preserved. A mangled single-line key makes every
  verification fail.
- **Algorithm must be RS256.** The credential's `algorithm` is `RS256` and the
  auth service signs with `RS256`. The signing algorithm and the credential
  algorithm must match, and the token must actually be signed with the private
  key that pairs with the stored public key.

Other quick checks: the token must be sent as `Authorization: Bearer <token>`,
and an expired token (TTL is `1h` by default) also yields 401.

---

## DEV-ONLY warnings

This repo is a **learning scaffold**, not a template for production:

- **Committed keys.** `keys/jwtRS256.key` (private) and `keys/jwtRS256.key.pub`
  (public) are checked into the repo so the stack runs with zero setup. A
  committed private key is never acceptable outside local learning. Regenerate
  with `scripts/gen-keys.sh` and keep private keys out of version control for any
  real use.
- **Committed passwords.** All database passwords (`kongpass`, `apppass`) and the
  seed account (`demo` / `demopass`) are hard-coded in `docker-compose.yml` and
  `db/init/01-schema.sql`. Treat them as throwaway.
- **Exposed Admin API.** Kong's Admin API on **8001** is published to the host
  with no auth. That is convenient for learning and dangerous anywhere else — in
  a real deployment it must be locked down.
