#!/bin/bash
set -e

VARIANT=$1
CONSTRAINT=$2

echo "===================================="
echo "Installing Drupal ${CONSTRAINT} on ${VARIANT}"
echo "===================================="

# Use service name instead of container name
SERVICE="drupal"

# Set the web root path based on variant
if [[ "$VARIANT" == *"frankenphp"* ]]; then
    WEBROOT="/app"
else
    WEBROOT="/var/www/html"
fi

# Wait for the container to be fully ready with health checks
echo "Waiting for container to be ready..."
for i in {1..12}; do
    if docker compose exec -T $SERVICE sh -c 'exit 0' 2>/dev/null; then
        echo "Container is ready!"
        break
    fi
    if [ $i -eq 12 ]; then
        echo "Container failed to become ready after 60 seconds"
        docker compose ps
        docker compose logs
        exit 1
    fi
    echo "Waiting for container... ($i/12)"
    sleep 5
done

echo "Creating Drupal project..."

# Clean directory first to ensure composer create-project works
# We use . to install in current directory
docker compose exec -T $SERVICE sh -c "rm -rf ${WEBROOT}/* ${WEBROOT}/.* 2>/dev/null || true"

# Create project
# We use specific arguments to avoid shell expansion issues
if [ -n "$CONSTRAINT" ]; then
    docker compose exec -T $SERVICE composer create-project drupal/recommended-project . "$CONSTRAINT" --no-interaction --no-dev
else
    docker compose exec -T $SERVICE composer create-project drupal/recommended-project . --no-interaction --no-dev
fi

# Require Drush
echo "Requiring Drush..."
docker compose exec -T $SERVICE composer require drush/drush --no-interaction

# Set proper permissions
echo "Setting up permissions..."
docker compose exec -T $SERVICE sh -c "mkdir -p ${WEBROOT}/web/sites/default/files && chmod -R 777 ${WEBROOT}/web/sites/default/files"
docker compose exec -T $SERVICE sh -c "chmod 777 ${WEBROOT}/web/sites/default"

# Install Drupal using drush with SQLite database file
echo "Installing Drupal using drush with SQLite..."
docker compose exec -T $SERVICE sh -c "cd ${WEBROOT} && vendor/bin/drush site:install minimal \
    --db-url="sqlite://sites/default/files/.ht.sqlite" \
    --site-name="Drupal Test Site" \
    --account-name=admin \
    --account-pass=admin \
    --yes \
    --no-interaction"

# Verify installation
echo "Verifying Drupal installation..."
DRUSH_STATUS=$(docker compose exec -T $SERVICE sh -c "cd ${WEBROOT} && vendor/bin/drush status --format=json" || echo "{}")

echo "Drush status output:"
echo "$DRUSH_STATUS"

# Check if bootstrap was successful
if echo "$DRUSH_STATUS" | grep -q "bootstrap"; then
    echo "✓ Drupal installation completed successfully"

    # Extract SQLite database path from drush status output
    # Format: "db-name": "/path/to/db.sqlite" or "db-name": "/path/to/db.sqlite",
    # We use sed to extract the value inside quotes after "db-name":
    DB_PATH=$(echo "$DRUSH_STATUS" | grep "\"db-name\"" | sed -E 's/.*"db-name": "([^"]+)".*/\1/')
    echo "Detected database path: $DB_PATH"

    if [ -n "$DB_PATH" ] && [[ "$DB_PATH" != *"null"* ]]; then
        # Get directory containing the database
        # Note: logic runs locally, so DB_DIR will be a local path string, which matches the container path structure
        DB_DIR=$(dirname "$DB_PATH")
        echo "Ensuring database directory is writable: $DB_DIR"
        # Ensure the directory containing the SQLite file is writable
        # We need to escape the variable for the remote shell execution
        docker compose exec -T $SERVICE sh -c "chmod 777 \"$DB_DIR\""
    fi
else
    echo "✗ Drupal installation may have issues"
    exit 1
fi

# Set permissions back to safer values but keep files directory writable
echo "Securing permissions..."
# sites/default should not be writable by web server (755)
docker compose exec -T $SERVICE sh -c "chmod 755 ${WEBROOT}/web/sites/default"
# Keep files directory fully writable (777) for testing - SQLite needs directory write access
docker compose exec -T $SERVICE sh -c "chmod -R 777 ${WEBROOT}/web/sites/default/files"

echo "===================================="
echo "Drupal installation complete"
echo "Admin user: admin"
echo "Admin pass: admin"
echo "===================================="
