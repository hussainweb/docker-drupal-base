# Agent Rules

## Repository layout

- `php8/<variant>/Dockerfile` — one image per variant: `apache-trixie`, `apache-bookworm`, `fpm-alpine`, `frankenphp-trixie` (the FrankenPHP variant also has a `Caddyfile`). Changes that apply to "the image" usually need to be made in every variant.
- `tests/` — the Docker Compose files and scripts (`install-drupal.sh`, `verify-drupal.sh`) that CI runs against a freshly built image.
- `.github/workflows/docker-buildx.yml` — the only build/test/publish workflow.
- `.grype.yaml` — vulnerability-scan ignores (currently upstream FrankenPHP Go dependencies).
- `build.sh` / `clean.sh` — manual local publishing helpers. `build.sh` uses `--push`; never run it.

## Testing: let GitHub Actions do it

Do not run full Docker builds locally; they are heavy on this machine. Open a PR and let CI build and test it.

What `docker-buildx.yml` does on a **pull request**:

- Builds every variant on native amd64 and arm64 runners with `load: true` (no push, no registry login).
- Starts the image with `tests/docker-compose*.yml`, installs Drupal with `tests/install-drupal.sh`, and runs `tests/verify-drupal.sh`.
- Scans the image with Grype (`severity-cutoff: high`, `only-fixed`, config in `.grype.yaml`); a finding fails the job.
- Builds only PHP 8.4 and 8.5. PHP 8.2 and 8.3 are built only on pushes to `main` and manual `workflow_dispatch`.
- Is skipped entirely when a PR touches only `**/*.md`, `.github/dependabot.yml`, `build.sh` or `clean.sh`.

On a **push to `main`** (i.e. after merge) the same workflow additionally builds all PHP versions, pushes per-arch digests to Docker Hub, merges them into the multi-arch tags (`php8.5-frankenphp-trixie`, `latest`, ...) and syncs the README to Docker Hub. Merging to `main` publishes images, so a change is only "done" once that run is green too.

Local checks that are cheap and fine: `docker buildx build --check`, `hadolint`, `caddy validate`/`caddy adapt` on a Caddyfile, `shellcheck`, `actionlint`.

## The downstream test repo

`hussainweb/test-docker-drupal-base` runs weekly and on its own pushes. It pulls the **published** images from Docker Hub (for example `hussainweb/drupal-base:php8.5-frankenphp-trixie`) and installs Drupal 11 and Drupal CMS 2 on apache-trixie, fpm-alpine and frankenphp-trixie (PHP 8.5, amd64 and arm64).

- It cannot test an unmerged change, because the image it uses only exists after merge.
- Its install and verify scripts are a copy of the ones in this repo, so it adds no coverage for image features. What it adds is real-world Drupal codebases (Drupal CMS 2, full-stack composer create-project on the host) against the published tags.
- Treat it as a post-merge smoke test, not a merge gate. Its Drupal CMS 2 legs were already failing on its scheduled run of 2026-09-27, before this file was written. Compare against that baseline before blaming an image change.
- Trigger it with `gh workflow run test-images.yml -R hussainweb/test-docker-drupal-base` after the `main` publish run has finished.

## Git and PR workflow

- Work on a branch, open a PR against `main`, wait for CI, merge when green. Squash-merge (the branch is deleted on merge).
- Conventional Commits for commit messages and PR titles (`feat:`, `fix:`, `ci:`, `build:`, `docs:`, `chore:`).
- Never add attribution to commits or PRs: no `Co-Authored-By: Claude ...` trailer and no "Generated with Claude Code" footer.
- Change PHP versions, base images and tool versions in every variant that has them, and update the README when the image's behaviour or configuration changes.
