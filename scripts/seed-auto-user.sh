#!/bin/bash
# Seed auto-login user for single-tenant Typebot deployment.
# Idempotent — safe to run on every container start.
# Gated by TYPEBOT_AUTO_LOGIN=true

set -euo pipefail

if [ "${TYPEBOT_AUTO_LOGIN:-}" != "true" ]; then
  echo "[seed-auto-user] TYPEBOT_AUTO_LOGIN is not 'true', skipping."
  exit 0
fi

if [ -z "${TYPEBOT_AUTO_SESSION_TOKEN:-}" ]; then
  echo "[seed-auto-user] ERROR: TYPEBOT_AUTO_SESSION_TOKEN is not set."
  exit 1
fi

if [ -z "${DATABASE_URL:-}" ]; then
  echo "[seed-auto-user] ERROR: DATABASE_URL is not set."
  exit 1
fi

# Extract connection params from DATABASE_URL (prisma format: postgresql://user:pass@host:port/db)
DB_URL="${DATABASE_URL}"

echo "[seed-auto-user] Seeding auto-login user..."

psql "${DB_URL}" <<SQL
-- Create auto-login user
INSERT INTO "User" (id, email, name, "createdAt", "updatedAt")
VALUES (
  'auto-admin-user-001',
  'admin@voicescreen.local',
  'VoiceScreen Admin',
  NOW(),
  NOW()
)
ON CONFLICT (id) DO NOTHING;

-- Create workspace
INSERT INTO "Workspace" (id, name, plan, "createdAt", "updatedAt")
VALUES (
  'auto-workspace-001',
  'VoiceScreen',
  'UNLIMITED',
  NOW(),
  NOW()
)
ON CONFLICT (id) DO NOTHING;

-- Link user to workspace as ADMIN
INSERT INTO "MemberInWorkspace" ("userId", "workspaceId", role, "createdAt", "updatedAt")
VALUES (
  'auto-admin-user-001',
  'auto-workspace-001',
  'ADMIN',
  NOW(),
  NOW()
)
ON CONFLICT ("userId", "workspaceId") DO NOTHING;

-- Create persistent session (expires in 10 years)
INSERT INTO "Session" (id, "sessionToken", "userId", expires)
VALUES (
  'auto-session-001',
  '${TYPEBOT_AUTO_SESSION_TOKEN}',
  'auto-admin-user-001',
  NOW() + INTERVAL '10 years'
)
ON CONFLICT (id) DO UPDATE SET
  "sessionToken" = EXCLUDED."sessionToken",
  expires = EXCLUDED.expires;
SQL

echo "[seed-auto-user] Done. Auto-login user seeded successfully."
