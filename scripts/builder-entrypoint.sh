#!/bin/bash

cd apps/builder;
node  -e "const { configureRuntimeEnv } = require('next-runtime-env/build/configure'); configureRuntimeEnv();"
cd ../..;

./node_modules/.bin/prisma migrate deploy --schema=packages/prisma/postgresql/schema.prisma;

if [ "${TYPEBOT_AUTO_LOGIN:-}" = "true" ]; then
  echo "[entrypoint] Running auto-login seed..."
  bash scripts/seed-auto-user.sh
fi

NODE_OPTIONS=--no-node-snapshot HOSTNAME=${HOSTNAME:-0.0.0.0} PORT=${PORT:-3000} node apps/builder/server.js;
