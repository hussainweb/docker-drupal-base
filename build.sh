#!/usr/bin/env bash

dir=$(dirname $0)

set -ex

export DOCKER_BUILDKIT=1

# Keep in sync with the PHP 8.6 pie_packages in .github/workflows/docker-buildx.yml.
PIE_PACKAGES_PHP86="apcu/apcu:dev-master#fb2c942552a3f5dab7f4dea4afb5cf0831222c57 php-memcached/php-memcached:dev-master#0b52d3657140750fa0eddd20cdbfc6edc8fbdadd phpredis/phpredis:dev-develop#a6ce1e60b3e81ce3b25174aa5aaefd5590dc64fd pecl/yaml:dev-php7#a7a3b8680b8fbf0895fd63371a0ffc1305b1a5b8"

docker pull php:8.2-apache-bookworm
docker pull php:8.3-apache-bookworm
docker pull php:8.4-apache-bookworm
docker pull php:8.5-apache-bookworm
docker pull php:8.6-apache-bookworm
docker pull php:8.4-apache-trixie
docker pull php:8.5-apache-trixie
docker pull php:8.6-apache-trixie
docker pull php:8.2-fpm-alpine
docker pull php:8.3-fpm-alpine
docker pull php:8.4-fpm-alpine
docker pull php:8.5-fpm-alpine
docker pull php:8.6-fpm-alpine
docker pull dunglas/frankenphp:php8.4-trixie
docker pull dunglas/frankenphp:php8.5-trixie
docker pull dunglas/frankenphp:php8.6-trixie
docker pull composer:2

docker buildx create --use --name drupal-base-builder

docker buildx build --push --platform linux/amd64,linux/arm64 --tag hussainweb/drupal-base:php8.2-apache-bookworm --build-arg PHP_VERSION=8.2 ${dir}/php8/apache-bookworm/
docker buildx build --push --platform linux/amd64,linux/arm64 --tag hussainweb/drupal-base:php8.3-apache-bookworm --build-arg PHP_VERSION=8.3 ${dir}/php8/apache-bookworm/
docker buildx build --push --platform linux/amd64,linux/arm64 --tag hussainweb/drupal-base:php8.4-apache-bookworm --build-arg PHP_VERSION=8.4 ${dir}/php8/apache-bookworm/
docker buildx build --push --platform linux/amd64,linux/arm64 --tag hussainweb/drupal-base:php8.5-apache-bookworm --build-arg PHP_VERSION=8.5 ${dir}/php8/apache-bookworm/
docker buildx build --push --platform linux/amd64,linux/arm64 --tag hussainweb/drupal-base:php8.6-apache-bookworm --build-arg PHP_VERSION=8.6 --build-arg PIE_PACKAGES="${PIE_PACKAGES_PHP86}" ${dir}/php8/apache-bookworm/

docker buildx build --push --platform linux/amd64,linux/arm64 --tag hussainweb/drupal-base:php8.2 --tag hussainweb/drupal-base:php8.2-apache-trixie --build-arg PHP_VERSION=8.2 ${dir}/php8/apache-trixie/
docker buildx build --push --platform linux/amd64,linux/arm64 --tag hussainweb/drupal-base:php8.3 --tag hussainweb/drupal-base:php8.3-apache-trixie --build-arg PHP_VERSION=8.3 ${dir}/php8/apache-trixie/
docker buildx build --push --platform linux/amd64,linux/arm64 --tag hussainweb/drupal-base:php8.4 --tag hussainweb/drupal-base:php8.4-apache-trixie --build-arg PHP_VERSION=8.4 ${dir}/php8/apache-trixie/
docker buildx build --push --platform linux/amd64,linux/arm64 --tag hussainweb/drupal-base:php8.5 --tag hussainweb/drupal-base:php8.5-apache-trixie --tag hussainweb/drupal-base:latest --build-arg PHP_VERSION=8.5 ${dir}/php8/apache-trixie/
docker buildx build --push --platform linux/amd64,linux/arm64 --tag hussainweb/drupal-base:php8.6 --tag hussainweb/drupal-base:php8.6-apache-trixie --build-arg PHP_VERSION=8.6 --build-arg PIE_PACKAGES="${PIE_PACKAGES_PHP86}" ${dir}/php8/apache-trixie/

docker buildx build --push --platform linux/amd64,linux/arm64 --tag hussainweb/drupal-base:php8.2-alpine --tag hussainweb/drupal-base:php8.2-fpm-alpine --build-arg PHP_VERSION=8.2 ${dir}/php8/fpm-alpine/
docker buildx build --push --platform linux/amd64,linux/arm64 --tag hussainweb/drupal-base:php8.3-alpine --tag hussainweb/drupal-base:php8.3-fpm-alpine --build-arg PHP_VERSION=8.3 ${dir}/php8/fpm-alpine/
docker buildx build --push --platform linux/amd64,linux/arm64 --tag hussainweb/drupal-base:php8.4-alpine --tag hussainweb/drupal-base:php8.4-fpm-alpine --build-arg PHP_VERSION=8.4 ${dir}/php8/fpm-alpine/
docker buildx build --push --platform linux/amd64,linux/arm64 --tag hussainweb/drupal-base:php8.5-alpine --tag hussainweb/drupal-base:php8.5-fpm-alpine --tag hussainweb/drupal-base:latest-alpine --build-arg PHP_VERSION=8.5 ${dir}/php8/fpm-alpine/
docker buildx build --push --platform linux/amd64,linux/arm64 --tag hussainweb/drupal-base:php8.6-alpine --tag hussainweb/drupal-base:php8.6-fpm-alpine --build-arg PHP_VERSION=8.6 --build-arg PIE_PACKAGES="${PIE_PACKAGES_PHP86}" ${dir}/php8/fpm-alpine/

docker buildx build --push --platform linux/amd64,linux/arm64 --tag hussainweb/drupal-base:php8.4-frankenphp-trixie --build-arg PHP_VERSION=8.4 ${dir}/php8/frankenphp-trixie/
docker buildx build --push --platform linux/amd64,linux/arm64 --tag hussainweb/drupal-base:php8.5-frankenphp-trixie --build-arg PHP_VERSION=8.5 ${dir}/php8/frankenphp-trixie/
docker buildx build --push --platform linux/amd64,linux/arm64 --tag hussainweb/drupal-base:php8.6-frankenphp-trixie --build-arg PHP_VERSION=8.6 --build-arg PIE_PACKAGES="${PIE_PACKAGES_PHP86}" ${dir}/php8/frankenphp-trixie/

docker buildx rm drupal-base-builder
