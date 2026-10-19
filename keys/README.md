# JWT signing keys — DEV-ONLY

This directory holds the RS256 keypair used by the auth service to sign JWTs and
by Kong (jwt plugin) to verify them.

- `jwtRS256.key` — RSA 2048 private key (PEM). Used by the auth service to sign tokens (RS256).
- `jwtRS256.key.pub` — RSA public key (PEM). Posted to the Kong Admin API as the credential's `rsa_public_key`.

## DEV-ONLY — do not use in production

**These keys are committed intentionally for local development and learning only.**
They are NOT secret and MUST NOT be used in any real or production environment.

To rotate / regenerate them, run from the repo root:

```bash
./scripts/gen-keys.sh
```

`gen-keys.sh` requires `openssl`. On a Windows host without openssl, generate via Docker:

```bash
docker run --rm -v "${PWD}:/w" -w /w alpine/openssl \
  genpkey -algorithm RSA -pkeyopt rsa_keygen_bits:2048 -out keys/jwtRS256.key
docker run --rm -v "${PWD}:/w" -w /w alpine/openssl \
  rsa -in keys/jwtRS256.key -pubout -out keys/jwtRS256.key.pub
```
