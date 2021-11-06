#!/usr/bin/env bash

dir=$(dirname $0)

set -ex

export DOCKER_BUILDKIT=1

docker pull php:7.3-apache-buster
docker pull php:7.4-apache-buster
docker pull php:8.0-apache-buster
docker pull composer:2

docker buildx create --use --name drupal-base-builder

docker buildx build --push --platform linux/amd64,linux/arm64 --tag hussainweb/drupal-base:php7.4 --build-arg PHP_VERSION=7.3-apache-buster ${dir}/php7.3/apache/
docker buildx build --push --platform linux/amd64,linux/arm64 --tag hussainweb/drupal-base:php7.4 --build-arg PHP_VERSION=7.4-apache-buster ${dir}/php7.4/apache/
docker buildx build --push --platform linux/amd64,linux/arm64 --tag hussainweb/drupal-base:php8.0 --tag hussainweb/drupal-base:latest --build-arg PHP_VERSION=8.0-apache-buster ${dir}/php7.4/apache/

docker buildx rm drupal-base-builder
