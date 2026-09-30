#!/bin/bash
# Checks the opt-in Coraza WAF of the FrankenPHP variant.
#
# Usage: verify-frankenphp-waf.sh default|enabled|capability <image>
#
#   default     run against the site started without WAF_SNIPPET (behaviour unchanged)
#   enabled     run against the site started with docker-compose.frankenphp-waf.yml
#   capability  check the file capability of the binary in the image
set -u

MODE=${1:-}
IMAGE=${2:-}
BASE_URL="http://localhost:8080"
SERVICE="drupal"
FAILED=0

pass() { echo "PASSED: $1"; }
fail() { echo "FAILED: $1"; FAILED=1; }

check() { # description, expected, actual
    if [ "$2" = "$3" ]; then pass "$1 ($3)"; else fail "$1 (expected '$2', got '$3')"; fi
}

check_contains() { # description, needle, haystack
    if printf '%s' "$3" | grep -qF -- "$2"; then pass "$1"; else fail "$1 (missing '$2')"; fi
}

status() { curl -s -o /dev/null -w '%{http_code}' "$@"; }

wait_for_web() {
    for _ in $(seq 1 30); do
        code=$(status "$BASE_URL/")
        [ "$code" != "000" ] && return 0
        sleep 2
    done
    echo "Web server did not come up"
    docker compose logs "$SERVICE" || true
    exit 1
}

# The WAF logs every rule it matches; a 403 alone could also come from the
# Caddyfile's own hardening (for example /.env), so look for the rule id.
waf_logged() { # description, rule id
    if docker compose logs "$SERVICE" 2>&1 | grep -E "id[\": ]+$2\b" | grep -q .; then
        pass "$1 (WAF log has rule $2)"
    else
        fail "$1 (no WAF log entry for rule $2)"
    fi
}

# True when the WAF logged a violation for this exact path.
waf_blocked() { # path
    docker compose logs "$SERVICE" 2>&1 | grep 'WAF rule violation detected' | grep -qF "\"uri\":\"$1\""
}

# Brotli is only negotiated for compressible responses of a minimum size.
brotli() {
    curl -s -o /dev/null -D - -H 'Accept-Encoding: br' "$BASE_URL/" | tr -d '\r' | grep -i '^content-encoding:'
}

case "$MODE" in
default)
    wait_for_web
    check "/ (normal page)" 200 "$(status -L "$BASE_URL/")"
    check "/user/login" 200 "$(status "$BASE_URL/user/login")"
    check "/wp-login.php is Drupal's own 404" 404 "$(status "$BASE_URL/wp-login.php")"
    check_contains "/wp-login.php body is rendered by Drupal" "Page not found" "$(curl -s "$BASE_URL/wp-login.php")"
    check "SQLi-looking query string is not blocked" 200 "$(status -L "$BASE_URL/?id=1%20UNION%20SELECT%20username,password%20FROM%20users--")"
    check "/xmlrpc.php" 404 "$(status "$BASE_URL/xmlrpc.php")"
    check_contains "Brotli is negotiated" "br" "$(brotli)"
    if docker compose logs "$SERVICE" 2>&1 | grep -qiE 'coraza|owasp'; then
        fail "WAF log entries with WAF disabled"
    else
        pass "no WAF log entries with WAF disabled"
    fi
    ;;
enabled)
    wait_for_web
    # Blocked by the default rules (10-scanner-paths.conf)
    check "/wp-login.php" 403 "$(status "$BASE_URL/wp-login.php")"
    check "/xmlrpc.php" 403 "$(status "$BASE_URL/xmlrpc.php")"
    check "/.env" 403 "$(status "$BASE_URL/.env")"
    check "/.git/config" 403 "$(status "$BASE_URL/.git/config")"
    check "/wp-admin/" 403 "$(status "$BASE_URL/wp-admin/")"
    check "/vendor/phpunit/src/Util/PHP/eval-stdin.php" 403 "$(status "$BASE_URL/vendor/phpunit/src/Util/PHP/eval-stdin.php")"
    check "PHP through PATH_INFO of a front controller name" 403 "$(status "$BASE_URL/wp-login.php/index.php")"
    check "PHP hidden in an encoded slash" 403 "$(status "$BASE_URL/wp-login.php%2findex.php")"
    check "PHP with a suffix after .php" 403 "$(status "$BASE_URL/wp-login.php;.png")"
    check "PHP in another case" 403 "$(status "$BASE_URL/Wp-Login.PHP")"
    check "PHP in the files directory" 403 "$(status "$BASE_URL/sites/default/files/x.php")"
    waf_logged "/wp-login.php" 10001
    waf_logged "/.env" 10002
    waf_logged "/wp-admin/" 10003
    # CRS: SQL injection in the query string
    check "SQLi in the query string" 403 "$(status "$BASE_URL/?id=1%20UNION%20SELECT%20username,password%20FROM%20users--")"
    check "XSS in the query string" 403 "$(status "$BASE_URL/?q=%3Cscript%3Ealert(1)%3C/script%3E")"
    # Project rules from /etc/frankenphp/waf/rules/
    check "project rule 90001" 403 "$(status "$BASE_URL/project-rule-test")"
    # Drupal keeps working
    check "/ (normal page)" 200 "$(status -L "$BASE_URL/")"
    check "/user/login" 200 "$(status "$BASE_URL/user/login")"
    check "/user/login with a normal query string" 200 "$(status "$BASE_URL/user/login?destination=/node/1&page=2")"
    check "/index.php" 200 "$(status -L "$BASE_URL/index.php")"
    check "/index.php/user/login (PATH_INFO)" 200 "$(status "$BASE_URL/index.php/user/login")"
    check "/core/misc/drupal.js" 200 "$(status "$BASE_URL/core/misc/drupal.js")"
    check "/core/themes/olivero/logo.svg" 200 "$(status "$BASE_URL/core/themes/olivero/logo.svg")"
    check "/robots.txt" 200 "$(status "$BASE_URL/robots.txt")"
    check "/.well-known/x is not blocked by the WAF" 404 "$(status "$BASE_URL/.well-known/x")"
    # The front controllers are not blocked by the WAF (Drupal itself may
    # deny access, redirect or fail without a session)
    for path in /update.php /core/install.php /core/rebuild.php /core/authorize.php; do
        code=$(status "$BASE_URL$path")
        if [ "$code" = "403" ] && waf_blocked "$path"; then
            fail "$path was blocked by the WAF"
        else
            pass "$path not blocked by the WAF ($code)"
        fi
    done
    # /wp-json is dropped from the default rule by the project file
    check "/wp-json (rule 10003 removed by the project)" 404 "$(status "$BASE_URL/wp-json")"
    check "/wp-content (project copy of the rule)" 403 "$(status "$BASE_URL/wp-content/x")"
    check_contains "Brotli is negotiated" "br" "$(brotli)"
    ;;
capability)
    [ -n "$IMAGE" ] || { echo "image required"; exit 2; }
    caps=$(docker run --rm --entrypoint getcap "$IMAGE" /usr/local/bin/frankenphp 2>&1)
    check_contains "frankenphp keeps cap_net_bind_service" "cap_net_bind_service" "$caps"
    mods=$(docker run --rm --entrypoint frankenphp "$IMAGE" list-modules 2>&1)
    check_contains "WAF module is in the binary" "http.handlers.waf" "$mods"
    check_contains "Brotli encoder is in the binary" "http.encoders.br" "$mods"
    ;;
*)
    echo "Usage: $0 default|enabled|capability <image>"
    exit 2
    ;;
esac

exit "$FAILED"
