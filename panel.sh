#!/usr/bin/env bash
# 🚀 XreatLabs Pterodactyl Panel Installer
# Author: Ahmadisog

set -euo pipefail

echo "🔧 Installing XreatLabs Panel with Docker (fixed drop/migrate flow)..."

# === CONFIG - change these before running ===
ADMIN_EMAIL="admin@xreatlabs.com"
ADMIN_USERNAME="xreatadmin"
ADMIN_FIRSTNAME="Xreat"
ADMIN_LASTNAME="Labs"
ADMIN_PASSWORD="SuperSecureAdmin123"

DB_PASSWORD="SuperSecurePass123"
DB_ROOT_PASSWORD="RootSecurePass123"
# ============================================

# Create working folder
mkdir -p ./panel
cd ./panel || exit 1

# Create docker-compose.yml (uses variable expansion)
cat <<EOF > docker-compose.yml
version: '3.8'

services:
  database:
    image: mariadb:10.11
    restart: unless-stopped
    command: --default-authentication-plugin=mysql_native_password
    volumes:
      - "./data/database:/var/lib/mysql"
    environment:
      MYSQL_ROOT_PASSWORD: "${DB_ROOT_PASSWORD}"
      MYSQL_DATABASE: "panel"
      MYSQL_USER: "pterodactyl"
      MYSQL_PASSWORD: "${DB_PASSWORD}"
    healthcheck:
      test: ["CMD-SHELL", "mysqladmin ping -h localhost -u pterodactyl -p'${DB_PASSWORD}' || exit 1"]
      interval: 5s
      timeout: 5s
      retries: 20

  cache:
    image: redis:alpine
    restart: unless-stopped

  panel:
    image: ghcr.io/pterodactyl/panel:latest
    restart: unless-stopped
    ports:
      - "8080:80"
    depends_on:
      database:
        condition: service_healthy
      cache:
        condition: service_started
    volumes:
      - "./data/var:/app/var/"
      - "./data/nginx:/etc/nginx/http.d/"
      - "./data/certs:/etc/letsencrypt/"
      - "./data/logs:/app/storage/logs"
    environment:
      APP_URL: "http://localhost:8080"
      APP_TIMEZONE: "UTC"
      APP_SERVICE_AUTHOR: "support@xreatlabs.com"
      TRUSTED_PROXIES: "*"
      MAIL_FROM: "support@xreatlabs.com"
      MAIL_DRIVER: "smtp"
      MAIL_HOST: "mail"
      MAIL_PORT: "1025"
      MAIL_USERNAME: ""
      MAIL_PASSWORD: ""
      MAIL_ENCRYPTION: "false"
      DB_HOST: "database"
      DB_PORT: "3306"
      DB_DATABASE: "panel"
      DB_USERNAME: "pterodactyl"
      DB_PASSWORD: "${DB_PASSWORD}"
      APP_ENV: "production"
      CACHE_DRIVER: "redis"
      SESSION_DRIVER: "redis"
      QUEUE_DRIVER: "redis"
      REDIS_HOST: "cache"
EOF

# Ensure data folders exist
mkdir -p ./data/{database,var,nginx,certs,logs}

# Clean previous run (remove anonymous containers/volumes)
docker compose down -v || true

# Start containers
docker compose up -d

# Wait for DB to accept connections (retry loop)
echo "⏳ Waiting for database to accept connections..."
for i in $(seq 1 60); do
  if docker compose exec -T database mysql -u pterodactyl -p"${DB_PASSWORD}" -e "SELECT 1;" >/dev/null 2>&1; then
    echo "✅ Database reachable after $i checks."
    break
  fi
  if [ "$i" -eq 60 ]; then
    echo "❌ Database did not become ready in time (60 checks). Exiting."
    exit 1
  fi
  sleep 2
done

# Collect table names from information_schema (if any) and drop them safely
echo "🗑️ Checking for existing tables to drop..."
TABLES_RAW=$(docker compose exec -T database \
  mysql -u pterodactyl -p"${DB_PASSWORD}" -N -B \
  -e "SELECT TABLE_NAME FROM information_schema.tables WHERE table_schema='panel';" || true)

if [ -n "${TABLES_RAW}" ]; then
  echo "Found existing tables — dropping them safely..."
  # Build a single SQL string with many DROP TABLE IF EXISTS `name`; statements
  DROP_SQL="SET FOREIGN_KEY_CHECKS = 0; "
  # Loop line-by-line to preserve names (handles many tables)
  while IFS= read -r tbl; do
    # Skip empty lines
    [ -z "$tbl" ] && continue
    # Append DROP (with backticks to escape reserved names)
    DROP_SQL+="DROP TABLE IF EXISTS \`${tbl}\`; "
  done <<EOF
${TABLES_RAW}
EOF
  DROP_SQL+="SET FOREIGN_KEY_CHECKS = 1;"

  # Execute the drop SQL in one mysql client call (avoids stored-procs / outfile)
  docker compose exec -T database mysql -u pterodactyl -p"${DB_PASSWORD}" panel -e "${DROP_SQL}"
  echo "✅ All old tables dropped."
else
  echo "🔎 No existing tables found — fresh DB."
fi

# Run migrations and seed (non-transactional by using standard migrate; this avoids transactional locks)
echo "⚙️ Running migrations and seeds..."
docker compose exec panel php artisan migrate --seed --force --no-interaction

# Create admin user only if it does not already exist
echo "👤 Ensuring admin user exists..."
USER_COUNT=$(docker compose exec -T database \
  mysql -u pterodactyl -p"${DB_PASSWORD}" -N -B \
  -e "SELECT COUNT(*) FROM users WHERE email='${ADMIN_EMAIL}';" panel 2>/dev/null || echo "0")

if [ "${USER_COUNT}" = "" ]; then USER_COUNT="0"; fi

if [ "${USER_COUNT}" -eq 0 ]; then
  echo "Creating admin: ${ADMIN_USERNAME} (${ADMIN_EMAIL})"
  docker compose exec panel php artisan p:user:make \
    --email="${ADMIN_EMAIL}" \
    --username="${ADMIN_USERNAME}" \
    --name-first="${ADMIN_FIRSTNAME}" \
    --name-last="${ADMIN_LASTNAME}" \
    --password="${ADMIN_PASSWORD}" \
    --admin=1 \
    --no-interaction
  echo "✅ Admin created."
else
  echo "ℹ️ Admin user already exists — skipping creation."
fi

cat <<EOM

✅ XreatLabs Panel installation finished!

Panel URL: http://localhost:8080

Admin credentials:
  Email:    ${ADMIN_EMAIL}
  Username: ${ADMIN_USERNAME}
  Password: ${ADMIN_PASSWORD}

Important:
- Change these passwords immediately after first login.
- If you run inside CodeSandbox, Port 8080 and Docker support may be limited — this script is intended for VPS/docker hosts.

EOM
