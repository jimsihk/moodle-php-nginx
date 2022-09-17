# Moodle on Alpine Linux

[![Docker Pulls](https://img.shields.io/docker/pulls/jimsihk/alpine-moodle.svg)](https://hub.docker.com/r/jimsihk/alpine-moodle/)
![Docker Image Size](https://img.shields.io/docker/image-size/jimsihk/alpine-moodle)
![nginx 1.22](https://img.shields.io/badge/nginx-1.22-brightgreen.svg)
![php 8.0.23](https://img.shields.io/badge/php-8.0.23-brightgreen.svg)
![moodle-4.0.4+](https://img.shields.io/badge/moodle-4.0.4+-yellow)
![License MIT](https://img.shields.io/badge/license-MIT-blue.svg)

Moodle setup for Docker, build on [Alpine Linux](http://www.alpinelinux.org/).

Repository: https://github.com/jimsihk/alpine-moodle


* Built on the lightweight image https://github.com/jimsihk/alpine-php-nginx
* Smaller Docker image size (+/-150MB)
* Uses PHP 8.0 for better performance, lower cpu usage & memory footprint
* Multi-arch support: 386, amd64, arm/v7, arm64, ppc64le, s390x
* Optimized for 100 concurrent users
* Optimized to only use resources when there's traffic (by using PHP-FPM's ondemand PM)
* Use of runit instead of supervisord to reduce memory footprint
* Configured cron to run as non-privileged user https://github.com/gliderlabs/docker-alpine/issues/381#issuecomment-621946699
* docker-compose sample with PostgreSQL
* Configuration via ENV variables
* Easily upgradable to new Moodle versions (via `MOODLE_GIT_URL` and `MOODLE_GIT_BRANCH`) with auto upgrade at docker start
* The servers Nginx, PHP-FPM run under a non-privileged user (nobody) to make it more secure
* The logs of all the services are redirected to the output of the Docker container (visible with `docker logs -f <container name>`)
* Follows the KISS principle (Keep It Simple, Stupid) to make it easy to understand and adjust the image to your needs

## Usage

Start the Docker containers:

    docker-compose up

Login on the system using the provided credentials (ENV vars)

## Configuration
Define the ENV variables in docker-compose.yml file

| Variable Name               | Default              | Description                                                              |
|-----------------------------|----------------------|--------------------------------------------------------------------------|
| LANG                        | en_US.UTF-8          |                                                                          |
| LANGUAGE                    | en_US:en             |                                                                          |
| SITE_URL                    | http://localhost     | Sets the public site url                                                 |
| SSLPROXY                    | false                | Disable SSL proxy to avod site loop. Ej. Cloudfare                       |
| DB_TYPE                     | pgsql                | mysqli - pgsql - mariadb                                                 |
| DB_HOST                     | postgres             | DB_HOST Ej. db container name                                            |
| DB_PORT                     | 5432                 | Postgres=5432 - MySQL=3306                                               |
| DB_NAME                     | moodle               |                                                                          |
| DB_USER                     | moodle               |                                                                          |
| DB_PREFIX                   | mdl_                 | Database prefix. WARNING: don't use numeric values or moodle won't start |
| MOODLE_EMAIL                | user@example.com     |                                                                          |
| MOODLE_LANGUAGE             | en                   |                                                                          |
| MOODLE_SITENAME             | New-Site             |                                                                          |
| MOODLE_USERNAME             | moodleuser           |                                                                          |
| MOODLE_PASSWORD             | PLEASE_CHANGEME      |                                                                          |
| SMTP_HOST                   | smtp.gmail.com       |                                                                          |
| SMTP_PORT                   | 587                  |                                                                          |
| SMTP_USER                   | your_email@gmail.com |                                                                          |
| SMTP_PASSWORD               | your_password        |                                                                          |
| SMTP_PROTOCOL               | tls                  |                                                                          |
| MOODLE_MAIL_NOREPLY_ADDRESS | noreply@localhost    |                                                                          |
| MOODLE_MAIL_PREFIX          | [moodle]             |                                                                          |
| client_max_body_size        | 50M                  |                                                                          |
| post_max_size               | 50M                  |                                                                          |
| upload_max_filesize         | 50M                  |                                                                          |
| max_input_vars              | 5000                 |                                                                          |
| SESSION_CACHE_TYPE          |                      | Optionally sets shared session cache store: memcached, redis, database   |
| SESSION_CACHE_HOST          |                      | Hostname of the external cache store, required for memcached and redis   |
| SESSION_CACHE_PORT          |                      | Memcached=11211, Redis=6379, required for memcached and redis            |
| SESSION_CACHE_PREFIX        | mdl                  | Cache prefix                                                             |
| SESSION_CACHE_AUTH          |                      | Authentication key for cache store, may be required for redis            |
| AUTO_UPDATE_MOODLE          | true                 | Set to false to disable checking and updating Moodle at docker start     |
