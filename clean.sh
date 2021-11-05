#!/usr/bin/env bash

docker rmi php:7.3-apache-buster
docker rmi php:7.4-apache-buster
docker rmi php:8.0-apache-buster
docker rmi composer:2

docker rmi hussainweb/drupal-base:php7.3
docker rmi hussainweb/drupal-base:php7.4
docker rmi hussainweb/drupal-base:php8.0
docker rmi hussainweb/drupal-base:latest
