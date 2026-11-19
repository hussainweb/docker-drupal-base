//go:build tools

// Package modules exists only so Dependabot can track the Caddy modules that
// the FrankenPHP Dockerfile adds on top of upstream. The blank imports keep
// `go mod tidy` from dropping them. Nothing here is built into the image.
package modules

import (
	_ "github.com/corazawaf/coraza-caddy/v2"
	_ "github.com/mholt/caddy-ratelimit"
)
