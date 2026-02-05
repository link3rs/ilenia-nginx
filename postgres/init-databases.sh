#!/bin/bash
# Ilenia PostgreSQL Database Initialization Script
# Creates separate databases and users for auth-service and events-service
#
# This script runs automatically when the PostgreSQL container starts for the first time.
# It creates:
#   - ilenia_auth database with ilenia_auth_user
#   - ilenia_events database with ilenia_events_user
#
# Each user has full privileges ONLY on their respective database.

set -e

echo "=== Ilenia PostgreSQL Initialization ==="
echo "Creating databases and users..."

# Create auth database and user
psql -v ON_ERROR_STOP=1 --username "$POSTGRES_USER" --dbname "$POSTGRES_DB" <<-EOSQL
    -- Create auth user and database
    CREATE USER ilenia_auth_user WITH PASSWORD '${POSTGRES_AUTH_PASSWORD:-auth_secret}';
    CREATE DATABASE ilenia_auth OWNER ilenia_auth_user;

    -- Grant privileges
    GRANT ALL PRIVILEGES ON DATABASE ilenia_auth TO ilenia_auth_user;

    -- Connect to auth database and set default privileges
    \connect ilenia_auth
    GRANT ALL ON SCHEMA public TO ilenia_auth_user;
    ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT ALL ON TABLES TO ilenia_auth_user;
    ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT ALL ON SEQUENCES TO ilenia_auth_user;

    -- Create events user and database
    \connect postgres
    CREATE USER ilenia_events_user WITH PASSWORD '${POSTGRES_EVENTS_PASSWORD:-events_secret}';
    CREATE DATABASE ilenia_events OWNER ilenia_events_user;

    -- Grant privileges
    GRANT ALL PRIVILEGES ON DATABASE ilenia_events TO ilenia_events_user;

    -- Connect to events database and set default privileges
    \connect ilenia_events
    GRANT ALL ON SCHEMA public TO ilenia_events_user;
    ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT ALL ON TABLES TO ilenia_events_user;
    ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT ALL ON SEQUENCES TO ilenia_events_user;
EOSQL

echo "=== Ilenia databases created successfully ==="
echo "  - ilenia_auth (user: ilenia_auth_user)"
echo "  - ilenia_events (user: ilenia_events_user)"
