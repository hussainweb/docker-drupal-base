#!/bin/bash
# Don't use set -e so we can run debugging on test failures
set +e

VARIANT=$1

echo "===================================="
echo "Verifying Drupal installation on ${VARIANT}"
echo "===================================="

# Determine the base URL and use service name
BASE_URL="http://localhost:8080"
SERVICE="drupal"

# Set the web root path based on variant
if [[ "$VARIANT" == *"frankenphp"* ]]; then
    WEBROOT="/app"
else
    WEBROOT="/var/www/html"
fi

# Wait a bit for services to stabilize
sleep 3

# Function to test HTTP endpoint
test_endpoint() {
    local url=$1
    local description=$2
    local expected_code=${3:-200}
    
    echo -n "Testing $description... "
    
    # Use curl to test the endpoint
    response=$(curl -s -o /dev/null -w "%{http_code}" -L "$url" 2>&1 || echo "000")
    
    if [ "$response" = "$expected_code" ]; then
        echo "✓ PASSED (HTTP $response)"
        return 0
    else
        echo "✗ FAILED (Expected HTTP $expected_code, got HTTP $response)"
        return 1
    fi
}

# Function to test page content
test_content() {
    local url=$1
    local description=$2
    local search_term=$3
    
    echo -n "Testing $description for '$search_term'... "
    
    # Use curl to fetch the page content
    content=$(curl -s -L "$url" 2>&1 || echo "")
    
    if echo "$content" | grep -q "$search_term"; then
        echo "✓ PASSED"
        return 0
    else
        echo "✗ FAILED (Content not found)"
        echo "Page content preview:"
        echo "$content" | head -20
        return 1
    fi
}

# Track test results
TESTS_PASSED=0
TESTS_FAILED=0

echo ""
echo "Running HTTP endpoint tests..."
echo "--------------------------------"

# Test 1: Homepage returns 200
if test_endpoint "$BASE_URL" "Homepage"; then
    ((TESTS_PASSED++))
else
    ((TESTS_FAILED++))
    echo ""
    echo "=== DEBUGGING HTTP 500 ERROR ==="
    echo "--- Fetching page content with error details ---"
    curl -v "$BASE_URL" 2>&1 | head -50
    echo ""
    echo "--- Checking file permissions ---"
    # Find the SQLite file and list its permissions
    docker compose exec -T $SERVICE sh -c "find ${WEBROOT}/web/sites/default/files -name '.ht.sqlite' -exec ls -la {} \;" || true
    # List permissions of the directory containing the SQLite file
    docker compose exec -T $SERVICE sh -c "find ${WEBROOT}/web/sites/default/files -name '.ht.sqlite' -exec dirname {} \; | xargs ls -ld" || true
    echo ""
    echo "--- Checking web server user ---"
    docker compose exec -T $SERVICE sh -c 'ps aux | grep -E "(apache|httpd|nginx|php-fpm|frankenphp)" | grep -v grep | head -5' || true
    echo ""
    echo "--- Checking if web server user can write to files directory ---"
    docker compose exec -T $SERVICE sh -c "su -s /bin/sh www-data -c 'touch ${WEBROOT}/web/sites/default/files/test-write.txt && rm ${WEBROOT}/web/sites/default/files/test-write.txt && echo Write_test:_SUCCESS' 2>&1 || su -s /bin/sh apache -c 'touch ${WEBROOT}/web/sites/default/files/test-write.txt && rm ${WEBROOT}/web/sites/default/files/test-write.txt && echo Write_test:_SUCCESS' 2>&1 || echo Write_test:_FAILED" || true
    echo ""
    echo "--- Checking PHP error log (last 50 lines) ---"
    docker compose exec -T $SERVICE sh -c 'tail -50 /var/log/apache2/error.log 2>/dev/null || tail -50 /var/log/php-fpm/error.log 2>/dev/null || tail -50 /var/log/php8/error.log 2>/dev/null || echo "Could not find PHP error log"' || true
    echo ""
    echo "--- Checking Apache/Nginx error log (last 50 lines) ---"
    docker compose exec -T $SERVICE sh -c 'tail -50 /var/log/apache2/error.log 2>/dev/null || tail -50 /var/log/nginx/error.log 2>/dev/null || echo "Could not find web server error log"' || true
    echo ""
    echo "--- Checking Drupal logs directory ---"
    docker compose exec -T $SERVICE sh -c "ls -la ${WEBROOT}/web/sites/default/files/ 2>/dev/null | head -20" || true
    echo ""
    echo "--- Checking Drupal watchdog errors ---"
    docker compose exec -T $SERVICE sh -c "cd ${WEBROOT} && vendor/bin/drush watchdog:show --severity=Error --count=10 2>&1" || true
    echo ""
    echo "--- Checking SQLite database permissions ---"
    docker compose exec -T $SERVICE sh -c "ls -la ${WEBROOT}/web/sites/default/files/.ht.sqlite* 2>/dev/null" || true
    echo ""
    echo "--- Checking PHP modules loaded via web server ---"
    docker compose exec -T $SERVICE sh -c "echo '<?php header(\"Content-Type: text/plain\"); foreach (get_loaded_extensions() as \$ext) { echo \$ext . \"\\n\"; }' > ${WEBROOT}/web/check_modules.php" || true
    echo "Modules from web server:"
    curl -s "$BASE_URL/check_modules.php" 2>&1 | head -50
    echo ""
    echo "--- Checking PHP modules via CLI (for comparison) ---"
    docker compose exec -T $SERVICE sh -c 'php -m | grep -iE "(pdo|sqlite|opcache)"' || true
    echo "=== END DEBUGGING ==="
    echo ""
fi

# Test 2: User login page returns 200
if test_endpoint "$BASE_URL/user/login" "Login page"; then
    ((TESTS_PASSED++))
else
    ((TESTS_FAILED++))
fi

# Test 3: Admin page (should redirect to login with 200, or return 403 for unauthorized)
echo -n "Testing Admin page... "
ADMIN_RESPONSE=$(curl -s -o /dev/null -w "%{http_code}" -L "$BASE_URL/admin" 2>&1 || echo "000")
if [ "$ADMIN_RESPONSE" = "200" ] || [ "$ADMIN_RESPONSE" = "403" ]; then
    echo "✓ PASSED (HTTP $ADMIN_RESPONSE)"
    ((TESTS_PASSED++))
else
    echo "✗ FAILED (Expected HTTP 200 or 403, got HTTP $ADMIN_RESPONSE)"
    ((TESTS_FAILED++))
fi

# Test 4: Check for Drupal meta tag on homepage
if test_content "$BASE_URL" "Homepage content" "Drupal"; then
    ((TESTS_PASSED++))
else
    ((TESTS_FAILED++))
fi

# Test 5: Check status page via drush
echo -n "Testing Drupal status via drush... "
DRUSH_CHECK=$(docker compose exec -T $SERVICE sh -c "cd ${WEBROOT} && vendor/bin/drush status --fields=bootstrap 2>&1" || echo "")

if echo "$DRUSH_CHECK" | grep -q "Successful"; then
    echo "✓ PASSED"
    ((TESTS_PASSED++))
else
    echo "✗ FAILED"
    echo "Drush output: $DRUSH_CHECK"
    ((TESTS_FAILED++))
fi

# Test 6: Check PHP version in container
echo -n "Testing PHP availability... "
PHP_VERSION=$(docker compose exec -T $SERVICE php -v 2>&1 || echo "")

if echo "$PHP_VERSION" | grep -q "PHP"; then
    echo "✓ PASSED"
    echo "   PHP Version: $(echo "$PHP_VERSION" | head -1)"
    ((TESTS_PASSED++))
else
    echo "✗ FAILED"
    ((TESTS_FAILED++))
fi

# Test 7: Check required PHP extensions
echo -n "Testing required PHP extensions... "
REQUIRED_EXTENSIONS="gd pdo pdo_sqlite json opcache"
MISSING_EXTENSIONS=""

for ext in $REQUIRED_EXTENSIONS; do
    # Use case-insensitive matching and handle "Zend OPcache" naming
    if [ "$ext" = "opcache" ]; then
        if ! docker compose exec -T $SERVICE php -m | grep -qi "opcache"; then
            MISSING_EXTENSIONS="$MISSING_EXTENSIONS $ext"
        fi
    elif ! docker compose exec -T $SERVICE php -m | grep -qi "^$ext$"; then
        MISSING_EXTENSIONS="$MISSING_EXTENSIONS $ext"
    fi
done

if [ -z "$MISSING_EXTENSIONS" ]; then
    echo "✓ PASSED"
    ((TESTS_PASSED++))
else
    echo "✗ FAILED (Missing:$MISSING_EXTENSIONS)"
    ((TESTS_FAILED++))
fi

# Test 8: Check web root permissions
echo -n "Testing web root is readable... "
WEB_ROOT_CHECK=$(docker compose exec -T $SERVICE sh -c "test -r ${WEBROOT}/web/index.php && echo readable" || echo "")

if [ "$WEB_ROOT_CHECK" = "readable" ]; then
    echo "✓ PASSED"
    ((TESTS_PASSED++))
else
    echo "✗ FAILED"
    ((TESTS_FAILED++))
fi

# Summary
echo ""
echo "===================================="
echo "Test Results Summary"
echo "===================================="
echo "Tests passed: $TESTS_PASSED"
echo "Tests failed: $TESTS_FAILED"
echo "===================================="

if [ $TESTS_FAILED -eq 0 ]; then
    echo "✓ All tests passed!"
    exit 0
else
    echo "✗ Some tests failed!"
    exit 1
fi
