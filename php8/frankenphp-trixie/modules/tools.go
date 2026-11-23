//go:build tools

// Package modules exists only so Dependabot can track what the FrankenPHP
// Dockerfile builds: every module passed to xcaddy, that is the Caddy modules
// it adds on top of upstream (Coraza and caddy-ratelimit) and the ones
// upstream builds in (FrankenPHP, whose go.mod pins Caddy, plus Brotli,
// Mercure and Vulcain). Requiring them all makes Go resolve the same versions
// xcaddy does, so go.mod and go.sum match the shipped binary.
// The blank imports keep `go mod tidy` from dropping them. Nothing here is
// built into the image.
package modules

import (
	_ "github.com/corazawaf/coraza-caddy/v2"
	_ "github.com/dunglas/caddy-cbrotli"
	_ "github.com/dunglas/frankenphp/caddy"
	_ "github.com/dunglas/mercure/caddy"
	_ "github.com/dunglas/vulcain/caddy"
	_ "github.com/mholt/caddy-ratelimit"
)
