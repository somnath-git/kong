#!/usr/bin/env bash
# gen-keys.sh — generate a DEV-ONLY RS256 keypair for the Kong JWT auth scaffold.
#
# DEV-ONLY: the keys produced here are for local development/learning only.
# NEVER use them in production. Regenerate at any time by re-running this script.
#
# Usage:
#   ./scripts/gen-keys.sh
#
# Requires openssl. On a Windows host without openssl you can run it via Docker:
#   docker run --rm -v "$PWD":/w -w /w alpine/openssl ... (see keys/README.md)
set -euo pipefail

# Resolve repo root (parent of this script's directory) so it works from anywhere.
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"
KEYS_DIR="${ROOT_DIR}/keys"

mkdir -p "${KEYS_DIR}"

# Private key: RSA 2048 (PKCS#8 PEM).
openssl genpkey -algorithm RSA -pkeyopt rsa_keygen_bits:2048 -out "${KEYS_DIR}/jwtRS256.key"

# Public key derived from the private key (PEM).
openssl rsa -in "${KEYS_DIR}/jwtRS256.key" -pubout -out "${KEYS_DIR}/jwtRS256.key.pub"

echo "Generated DEV-ONLY keypair:"
echo "  ${KEYS_DIR}/jwtRS256.key"
echo "  ${KEYS_DIR}/jwtRS256.key.pub"
