#!/usr/bin/env bash

dir=$(dirname $0)

set -ex

export DOCKER_BUILDKIT=1

docker pull php:8.0-apache-bullseye
docker pull php:8.1-apache-bullseye
docker pull php:8.2-apache-bullseye
docker pull composer:2

docker buildx create --use --name drupal-base-builder

docker buildx build --push --platform linux/amd64,linux/arm64 --tag hussainweb/drupal-base:php8.0 --build-arg PHP_VERSION=8.0-apache-bullseye ${dir}/php8/apache/
docker buildx build --push --platform linux/amd64,linux/arm64 --tag hussainweb/drupal-base:php8.1 --build-arg PHP_VERSION=8.1-apache-bullseye ${dir}/php8/apache/
docker buildx build --push --platform linux/amd64,linux/arm64 --tag hussainweb/drupal-base:php8.2 --tag hussainweb/drupal-base:latest --build-arg PHP_VERSION=8.2-apache-bullseye ${dir}/php8/apache/

docker buildx rm drupal-base-builder
