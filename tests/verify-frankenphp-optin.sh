#!/bin/bash
# Checks the opt-in FrankenPHP features (basic auth, noindex, PHP memory limit,
# rate limiting).
#
# Usage: verify-frankenphp-optin.sh default|optin|ratelimit|failclosed <image>
#
#   default     run against the site started with none of the variables set
#   optin       run against the site started with docker-compose.frankenphp-optin.yml
#               (needs BASIC_AUTH_PASSWORD in the environment)
#   ratelimit   run against the site started with docker-compose.frankenphp-ratelimit.yml
#   failclosed  run the image directly with incomplete basic auth settings
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

check_not_contains() { # description, needle, haystack
    if printf '%s' "$3" | grep -qF -- "$2"; then fail "$1 (found '$2')"; else pass "$1"; fi
}

wait_for_web() {
    for _ in $(seq 1 30); do
        code=$(curl -s -o /dev/null -w '%{http_code}' "$BASE_URL/" || true)
        [ "$code" != "000" ] && return 0
        sleep 2
    done
    echo "Web server did not come up"
    docker compose logs "$SERVICE" || true
    exit 1
}

status() { # path, extra curl args
    local path=$1
    shift
    curl -s -o /dev/null -w '%{http_code}' "$@" "$BASE_URL$path"
}

# memory_limit as the web server sees it (a request), not the CLI.
web_memory_limit() { # extra curl args
    docker compose exec -T "$SERVICE" sh -c \
        "echo '<?php echo ini_get(\"memory_limit\");' > /app/web/memlimit.php"
    curl -s "$@" "$BASE_URL/memlimit.php"
}

case "$MODE" in
default)
    wait_for_web
    check "/ without credentials" 200 "$(curl -s -o /dev/null -w '%{http_code}' -L "$BASE_URL/")"
    headers=$(curl -si "$BASE_URL/")
    check_not_contains "/ has no X-Robots-Tag" "X-Robots-Tag: noindex" "$headers"
    robots=$(curl -s "$BASE_URL/robots.txt")
    check_contains "/robots.txt is Drupal's own" "Disallow: /core/" "$robots"
    check "web memory_limit is PHP's default" 128M "$(web_memory_limit)"
    check "CLI memory_limit" -1 "$(docker compose exec -T "$SERVICE" php -r 'echo ini_get("memory_limit");')"
    limited=0
    for _ in $(seq 1 20); do
        [ "$(status /user/login)" = 429 ] && limited=1
    done
    check "20 requests are not rate limited" 0 "$limited"
    ;;
optin)
    : "${BASIC_AUTH_PASSWORD:?BASIC_AUTH_PASSWORD must be set}"
    wait_for_web
    check "/ without credentials" 401 "$(curl -s -o /dev/null -w '%{http_code}' "$BASE_URL/")"
    headers=$(curl -si "$BASE_URL/")
    check_contains "401 carries X-Robots-Tag" "X-Robots-Tag: noindex, nofollow, noarchive" "$headers"
    check "/ with wrong credentials" 401 "$(curl -s -o /dev/null -w '%{http_code}' -u "demo:wrong" "$BASE_URL/")"
    check "/ with wrong user" 401 "$(curl -s -o /dev/null -w '%{http_code}' -u "other:${BASIC_AUTH_PASSWORD}" "$BASE_URL/")"
    check "/ with right credentials" 200 "$(curl -s -o /dev/null -w '%{http_code}' -L -u "demo:${BASIC_AUTH_PASSWORD}" "$BASE_URL/")"
    check "/user/login without credentials" 401 "$(curl -s -o /dev/null -w '%{http_code}' "$BASE_URL/user/login")"
    check "/robots.txt without credentials" 200 "$(curl -s -o /dev/null -w '%{http_code}' "$BASE_URL/robots.txt")"
    robots=$(curl -s "$BASE_URL/robots.txt")
    check_contains "/robots.txt disallows all" "Disallow: /" "$robots"
    check_not_contains "/robots.txt is not Drupal's" "Disallow: /core/" "$robots"
    check_contains "/robots.txt carries X-Robots-Tag" "X-Robots-Tag: noindex" "$(curl -si "$BASE_URL/robots.txt")"
    check "web memory_limit" 512M "$(web_memory_limit -u "demo:${BASIC_AUTH_PASSWORD}")"
    check "CLI memory_limit" -1 "$(docker compose exec -T "$SERVICE" php -r 'echo ini_get("memory_limit");')"
    # PID 1 is the web server after the entrypoint's exec; its own environment
    # is what PHP would inherit.
    if docker compose exec -T "$SERVICE" sh -c "tr '\0' '\n' < /proc/1/environ | grep -q '^BASIC_AUTH_PASSWORD='"; then
        fail "BASIC_AUTH_PASSWORD is unset in the server process"
    else
        pass "BASIC_AUTH_PASSWORD is unset in the server process"
    fi
    ;;
ratelimit)
    wait_for_web
    # The Docker network is trusted, so X-Forwarded-For picks the client. Each
    # check uses its own address, apart from the one wait_for_web used.
    a=(-H "X-Forwarded-For: 198.51.100.1")
    b=(-H "X-Forwarded-For: 198.51.100.2")
    for i in $(seq 1 5); do
        check "request $i of 5 is allowed" 200 "$(status /user/login "${a[@]}")"
    done
    check "request 6 is rate limited" 429 "$(status /user/login "${a[@]}")"
    check_contains "429 carries Retry-After" "Retry-After:" "$(curl -si "${a[@]}" "$BASE_URL/user/login")"
    check "static assets are not counted" 200 "$(status /core/misc/drupal.js "${a[@]}")"
    check "another client is allowed" 200 "$(status /user/login "${b[@]}")"
    check_contains "the log has the client" '"key":"198.51.100.1"' "$(docker compose logs "$SERVICE" 2>&1)"
    ;;
failclosed)
    [ -n "$IMAGE" ] || { echo "image required"; exit 2; }
    enabled=/etc/frankenphp/basic-auth/enabled.caddy
    for envs in "BASIC_AUTH_USER=demo" "BASIC_AUTH_PASSWORD=secret"; do
        out=$(docker run --rm -e "$envs" -e "BASIC_AUTH_SNIPPET=$enabled" "$IMAGE" 2>&1)
        rc=$?
        if [ "$rc" -ne 0 ]; then pass "exits non-zero with only $envs (rc=$rc)"; else fail "exits non-zero with only $envs"; fi
        check_contains "message for only $envs" "docker-drupal-entrypoint: basic auth is enabled" "$out"
    done
    ;;
*)
    echo "Usage: $0 default|optin|ratelimit|failclosed <image>"
    exit 2
    ;;
esac

exit "$FAILED"
