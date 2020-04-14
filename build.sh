#!/usr/bin/env bash

dir=$(dirname $0)

set -ex

export DOCKER_BUILDKIT=1

docker pull php:7.3-apache-buster
docker pull php:7.4-apache-buster
docker pull composer:1.10

docker build -t hussainweb/drupal-base:php7.3 --build-arg PHP_VERSION=7.3-apache-buster ${dir}/php7.3/apache/
docker build -t hussainweb/drupal-base:php7.4 --build-arg PHP_VERSION=7.4-apache-buster ${dir}/php7.4/apache/
docker tag hussainweb/drupal-base:php7.4 hussainweb/drupal-base:latest

docker push hussainweb/drupal-base:php7.3
docker push hussainweb/drupal-base:php7.4
docker push hussainweb/drupal-base:latest
