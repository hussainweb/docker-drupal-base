#!/usr/bin/env bash

docker rmi php:8.1-apache-bullseye
docker rmi php:8.2-apache-bullseye
docker rmi php:8.3-apache-bullseye
docker rmi php:8.4-apache-bullseye
docker rmi composer:2

docker rmi hussainweb/drupal-base:php8.1
docker rmi hussainweb/drupal-base:php8.2
docker rmi hussainweb/drupal-base:php8.3
docker rmi hussainweb/drupal-base:php8.4
docker rmi hussainweb/drupal-base:latest
