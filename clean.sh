#!/usr/bin/env bash

docker rmi php:8.2-apache-bookworm
docker rmi php:8.3-apache-bookworm
docker rmi php:8.4-apache-bookworm
docker rmi php:8.5-apache-bookworm
docker rmi php:8.2-apache-trixie
docker rmi php:8.3-apache-trixie
docker rmi php:8.4-apache-trixie
docker rmi php:8.5-apache-trixie
docker rmi php:8.2-fpm-alpine
docker rmi php:8.3-fpm-alpine
docker rmi php:8.4-fpm-alpine
docker rmi php:8.5-fpm-alpine
docker rmi dunglas/frankenphp:php8.4-trixie
docker rmi dunglas/frankenphp:php8.5-trixie
docker rmi composer:2

docker rmi hussainweb/drupal-base:php8.2
docker rmi hussainweb/drupal-base:php8.3
docker rmi hussainweb/drupal-base:php8.4
docker rmi hussainweb/drupal-base:php8.5
docker rmi hussainweb/drupal-base:php8.2-alpine
docker rmi hussainweb/drupal-base:php8.3-alpine
docker rmi hussainweb/drupal-base:php8.4-alpine
docker rmi hussainweb/drupal-base:php8.5-alpine
docker rmi hussainweb/drupal-base:php8.4-frankenphp-trixie
docker rmi hussainweb/drupal-base:php8.5-frankenphp-trixie
docker rmi hussainweb/drupal-base:latest
