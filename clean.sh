#!/usr/bin/env bash

docker rmi php:8.1-apache-bullseye
docker rmi php:8.2-apache-bullseye
docker rmi php:8.3-apache-bullseye
docker rmi php:8.4-apache-bullseye
docker rmi php:8.5-apache-bullseye
docker rmi php:8.1-fpm-alpine
docker rmi php:8.2-fpm-alpine
docker rmi php:8.3-fpm-alpine
docker rmi php:8.4-fpm-alpine
docker rmi php:8.5-fpm-alpine
docker rmi composer:2

docker rmi hussainweb/drupal-base:php8.1
docker rmi hussainweb/drupal-base:php8.2
docker rmi hussainweb/drupal-base:php8.3
docker rmi hussainweb/drupal-base:php8.4
docker rmi hussainweb/drupal-base:php8.5
docker rmi hussainweb/drupal-base:php8.1-alpine
docker rmi hussainweb/drupal-base:php8.2-alpine
docker rmi hussainweb/drupal-base:php8.3-alpine
docker rmi hussainweb/drupal-base:php8.4-alpine
docker rmi hussainweb/drupal-base:php8.5-alpine
docker rmi hussainweb/drupal-base:latest
