#!/usr/bin/env bash

dir=$(dirname $0)

set -ex

export DOCKER_BUILDKIT=1

docker pull php:7.3-apache-buster
docker pull composer:1.10

docker build -t hussainweb/drupal-base:php7.3 ${dir}/php7.3/apache/
docker tag hussainweb/drupal-base:php7.3 hussainweb/drupal-base:latest

docker push hussainweb/drupal-base:php7.3
docker push hussainweb/drupal-base:latest
