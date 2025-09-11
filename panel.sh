#!/usr/bin/env bash
# 🚀 XreatLabs Pterodactyl Panel Installer
# Maintainer: XreatLabs Team

set -euo pipefail

echo "🔧 Installing XreatLabs Panel with Docker..."

# === CONFIGURATION ===
ADMIN_EMAIL="admin@xreatlabs.com"
ADMIN_USERNAME="xreatadmin"
ADMIN_FIRSTNAME="Xreat"
ADMIN_LASTNAME="Labs"
ADMIN_PASSWORD="SuperSecureAdmin123"

DB_PASSWORD="SuperSecurePass123"
DB_ROOT_PASSWORD="RootSecurePass123"
# =====================

# Create working directory
mkdir -p ./panel
cd ./panel || exit 1

# docker-compose.yml
cat <<EOF > docker-compose.yml
version: '3.8'

services:
  database:
    image: mariadb:10.11
    restart: unless-stopped
    command: --default-authentication-plugin=mysql_native_password
    environment:
      MYSQL_ROOT_PASSWORD: "${DB_ROOT_PASSWORD}"
      MYSQL_DATABASE: "panel"
      MYSQL_USER: "pterodactyl"
      MYSQL_PASSWORD: "${DB_PASSWORD}"
    volumes:
      - "./data/database:/var/lib/mysql"
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
    volumes:
      - "./data/var:/app/var/"
      - "./data/nginx:/etc/nginx/http.d/"
      - "./data/certs:/etc/letsencrypt/"
      - "./data/logs:/app/storage/logs"
EOF

# Ensure data directories exist
mkdir -p ./data/{database,var,nginx,certs,logs}

# Clean up old stack
docker compose down -v || true

# Start services
docker compose up -d

# Wait for DB to be ready
echo "⏳ Waiting for database..."
for i in $(seq 1 60); do
  if docker compose exec -T database mysql -u pterodactyl -p"${DB_PASSWORD}" -e "SELECT 1;" >/dev/null 2>&1; then
    echo "✅ Database is ready."
    break
  fi
  if [ "$i" -eq 60 ]; then
    echo "❌ Database did not come online in time."
    exit 1
  fi
  sleep 2
done

# Drop and recreate the panel schema
echo "🧹 Resetting database schema..."
docker compose exec -T database \
  mysql -u root -p"${DB_ROOT_PASSWORD}" \
  -e "DROP DATABASE IF EXISTS panel; CREATE DATABASE panel CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;"

# Run migrations
echo "⚙️ Running migrations and seeds..."
docker compose exec panel php artisan migrate --seed --force --no-interaction

# Ensure admin user
echo "👤 Checking admin user..."
USER_COUNT=$(docker compose exec -T database \
  mysql -u pterodactyl -p"${DB_PASSWORD}" -N -B \
  -e "SELECT COUNT(*) FROM users WHERE email='${ADMIN_EMAIL}';" panel 2>/dev/null || echo "0")

if [ "$USER_COUNT" = "0" ]; then
  echo "Creating admin account..."
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
  echo "ℹ️ Admin already exists."
fi

cat <<EOM

🎉 XreatLabs Panel installed successfully!

Panel URL: http://localhost:8080

Login:
  Email:    ${ADMIN_EMAIL}
  Username: ${ADMIN_USERNAME}
  Password: ${ADMIN_PASSWORD}

⚠️ Remember to change these credentials after first login.
EOM
