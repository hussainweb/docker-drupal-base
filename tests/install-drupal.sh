#!/bin/bash
set -e

VARIANT=$1
DRUPAL_VERSION=$2

echo "===================================="
echo "Installing Drupal ${DRUPAL_VERSION} on ${VARIANT}"
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

# Check if composer.json exists, if not, create project
HAS_COMPOSER=$(docker compose exec -T $SERVICE sh -c "if [ -f ${WEBROOT}/composer.json ]; then echo 'yes'; else echo 'no'; fi")

if [ "$HAS_COMPOSER" = "no" ]; then
    echo "composer.json not found. Creating Drupal project..."

    # Determine version constraint from argument (e.g. 10.x -> ^10)
    CONSTRAINT=""
    MAJOR=${DRUPAL_VERSION%%.*}
    if [[ "$MAJOR" =~ ^[0-9]+$ ]]; then
        CONSTRAINT="^${MAJOR}"
    fi

    echo "Selected version constraint: ${CONSTRAINT:-latest}"

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
else
    echo "composer.json found. Skipping project creation."
fi

# Check if Drupal is already installed
INSTALLED=$(docker compose exec -T $SERVICE sh -c "if [ -f ${WEBROOT}/web/sites/default/settings.php ] && grep -q 'database' ${WEBROOT}/web/sites/default/settings.php 2>/dev/null; then echo 'yes'; else echo 'no'; fi" || echo "no")

if [ "$INSTALLED" = "yes" ]; then
    echo "Drupal appears to be already installed. Skipping installation."
    exit 0
fi

# Set proper permissions
echo "Setting up permissions..."
docker compose exec -T $SERVICE sh -c "mkdir -p ${WEBROOT}/web/sites/default/files && chmod -R 777 ${WEBROOT}/web/sites/default/files"
docker compose exec -T $SERVICE sh -c "chmod 777 ${WEBROOT}/web/sites/default"

# Install Drupal using drush with SQLite database file
echo "Installing Drupal using drush with SQLite..."
docker compose exec -T $SERVICE sh -c "cd ${WEBROOT} && vendor/bin/drush site:install minimal \
    --db-url="sqlite://localhost/sites/default/files/.ht.sqlite" \
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
