#!/usr/bin/env bash

dir=$(dirname $0)

set -ex

export DOCKER_BUILDKIT=1

docker pull php:8.1-apache-bookworm
docker pull php:8.2-apache-bookworm
docker pull php:8.3-apache-bookworm
docker pull php:8.4-apache-bookworm
docker pull php:8.1-fpm-alpine
docker pull php:8.2-fpm-alpine
docker pull php:8.3-fpm-alpine
docker pull php:8.4-fpm-alpine
docker pull composer:2

docker buildx create --use --name drupal-base-builder

docker buildx build --push --platform linux/amd64,linux/arm64 --tag hussainweb/drupal-base:php8.1 --build-arg PHP_VERSION=8.1-apache-bookworm ${dir}/php8/apache-bookworm/
docker buildx build --push --platform linux/amd64,linux/arm64 --tag hussainweb/drupal-base:php8.2 --build-arg PHP_VERSION=8.2-apache-bookworm ${dir}/php8/apache-bookworm/
docker buildx build --push --platform linux/amd64,linux/arm64 --tag hussainweb/drupal-base:php8.3 --build-arg PHP_VERSION=8.3-apache-bookworm ${dir}/php8/apache-bookworm/
docker buildx build --push --platform linux/amd64,linux/arm64 --tag hussainweb/drupal-base:php8.4 --tag hussainweb/drupal-base:latest --build-arg PHP_VERSION=8.4-apache-bookworm ${dir}/php8/fpm-alpine/
docker buildx build --push --platform linux/amd64,linux/arm64 --tag hussainweb/drupal-base:php8.1-alpine --build-arg PHP_VERSION=8.1-fpm-alpine ${dir}/php8/fpm-alpine/
docker buildx build --push --platform linux/amd64,linux/arm64 --tag hussainweb/drupal-base:php8.2-alpine --build-arg PHP_VERSION=8.2-fpm-alpine ${dir}/php8/fpm-alpine/
docker buildx build --push --platform linux/amd64,linux/arm64 --tag hussainweb/drupal-base:php8.3-alpine --build-arg PHP_VERSION=8.3-fpm-alpine ${dir}/php8/fpm-alpine/
docker buildx build --push --platform linux/amd64,linux/arm64 --tag hussainweb/drupal-base:php8.4-alpine --tag hussainweb/drupal-base:latest-alpine --build-arg PHP_VERSION=8.4-fpm-alpine ${dir}/php8/fpm-alpine/

docker buildx rm drupal-base-builder
