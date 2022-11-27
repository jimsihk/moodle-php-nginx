# Moodle on Alpine Linux

[![Docker Pulls](https://img.shields.io/docker/pulls/jimsihk/alpine-moodle.svg)](https://hub.docker.com/r/jimsihk/alpine-moodle/)
![Docker Image Size](https://img.shields.io/docker/image-size/jimsihk/alpine-moodle)
![nginx 1.22](https://img.shields.io/badge/nginx-1.22-brightgreen.svg)
![php 8.0](https://img.shields.io/badge/php-8.0-brightgreen.svg)
![moodle-4.0](https://img.shields.io/badge/moodle-4.0-yellow)
![License MIT](https://img.shields.io/badge/license-MIT-blue.svg)
[![Renovate](https://img.shields.io/badge/renovate-enabled-yellow.svg)](https://app.renovatebot.com/dashboard)

Moodle setup for Docker, build on [Alpine Linux](http://www.alpinelinux.org/).

Repository: https://github.com/jimsihk/alpine-moodle

* Based on official Moodle source https://github.com/moodle/moodle
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
* Easily upgradable to new Moodle versions (via `ARG_MOODLE_GIT_URL` and `ARG_MOODLE_GIT_BRANCH` at build time, `MOODLE_GIT_URL` and `MOODLE_GIT_BRANCH` at run time) with auto upgrade at docker start 
* Moodle plug-in installation via docker build argument `ARG_MOODLE_PLUGIN_LIST`
* The servers NGINX, PHP-FPM run under a non-privileged user (nobody) to make it more secure
* The logs of all the services are redirected to the output of the Docker container (visible with `docker logs -f <container name>`)
* Follows the KISS principle (Keep It Simple, Stupid) to make it easy to understand and adjust the image to your needs

## Usage

Start the Docker containers:

    docker-compose up

Login on the system using the provided credentials (ENV vars)

## Configuration
Define the ENV variables in docker-compose.yml file

| Variable Name               | Default              | Description                                                                                    |
|-----------------------------|----------------------|------------------------------------------------------------------------------------------------|
| LANG                        | en_US.UTF-8          |                                                                                                |
| LANGUAGE                    | en_US:en             |                                                                                                |
| SITE_URL                    | http://localhost     | Sets the public site URL                                                                       |
| SSLPROXY                    | false                | Disable SSL proxy to avod site loop. Ej. Cloudfare                                             |
| DB_TYPE                     | pgsql                | mysqli - pgsql - mariadb                                                                       |
| DB_HOST                     | postgres             | Database hostname Ej. db container name                                                        |
| DB_PORT                     | 5432                 | PostgresSQL=5432 - MySQL/MariaDB=3306                                                          |
| DB_NAME                     | moodle               | Database name                                                                                  |
| DB_USER                     | moodle               | Database login username                                                                        |
| DB_PASS                     | moodle               | Database login password                                                                        |
| DB_FETCHBUFFERSIZE          |                      | Set to 0 if using PostgresSQL poolers like PgBouncer in 'transaction' mode                     |
| DB_DBHANDLEOPTIONS          | false                | Set to true if using PostgresSQL poolers like PgBouncer which does not support sending options |
| DB_HOST_REPLICA             |                      | Database hostname of the read-only replica database                                            |
| DB_PORT_REPLICA             |                      | Database port of replica, left it empty to be same as DB_PORT                                  |
| DB_USER_REPLICA             |                      | Database login username of replica, left it empty to be same as DB_USER                        |
| DB_PASS_REPLICA             |                      | Database login password of replica, left it empty to be same as DB_PASS                        |
| DB_PREFIX                   | mdl_                 | Database prefix. WARNING: don't use numeric values or moodle won't start                       |
| MOODLE_EMAIL                | user@example.com     |                                                                                                |
| MOODLE_LANGUAGE             | en                   |                                                                                                |
| MOODLE_SITENAME             | New-Site             |                                                                                                |
| MOODLE_SHORTNAME            | moodle               |                                                                                                |
| MOODLE_USERNAME             | moodleuser           |                                                                                                |
| MOODLE_PASSWORD             | PLEASE_CHANGEME      |                                                                                                |
| SMTP_HOST                   | smtp.gmail.com       |                                                                                                |
| SMTP_PORT                   | 587                  |                                                                                                |
| SMTP_USER                   | your_email@gmail.com |                                                                                                |
| SMTP_PASSWORD               | your_password        |                                                                                                |
| SMTP_PROTOCOL               | tls                  |                                                                                                |
| MOODLE_MAIL_NOREPLY_ADDRESS | noreply@localhost    |                                                                                                |
| MOODLE_MAIL_PREFIX          | [moodle]             |                                                                                                |
| client_max_body_size        | 50M                  |                                                                                                |
| post_max_size               | 50M                  |                                                                                                |
| upload_max_filesize         | 50M                  |                                                                                                |
| max_input_vars              | 5000                 |                                                                                                |
| SESSION_CACHE_TYPE          |                      | Optionally sets shared session cache store: memcached, redis, database                         |
| SESSION_CACHE_HOST          |                      | Hostname of the external cache store, required for memcached and redis                         |
| SESSION_CACHE_PORT          |                      | Memcached=11211, Redis=6379, required for memcached and redis                                  |
| SESSION_CACHE_PREFIX        | mdl                  | Cache prefix                                                                                   |
| SESSION_CACHE_AUTH          |                      | Authentication key for cache store, may be required for redis                                  |
| AUTO_UPDATE_MOODLE          | true                 | Set to false to disable checking and updating Moodle at docker start                           |
| DISABLE_WEB_INSTALL_PLUGIN  | false                | Set to true to disable plugin installation via site admin UI                                   |

## Custom builds
### Moodle plugins

For installing plugins while building the main Dockerfile (slower), use `ARG_MOODLE_PLUGIN_LIST`:
```
docker buildx build . -t my_moodle_image:my_tag \
    --build-arg ARG_MOODLE_PLUGIN_LIST='mod_attendance mod_checklist mod_customcert block_checklist gradeexport_checklist'
```
For building only to install additional moodle plugins (faster), create a Dockerfile like the following and then build.
Example of `Dockerfile.plugins`:
```dockerfile
# Dockerfile.plugins
FROM jimsihk/alpine-moodle:dev

# Install additional plugins, a space separated arg, (optional)
# Run install-plugin-list with argument "-f" to force install 
#   if the plugin is not compatible with current Moodle version
ARG ARG_MOODLE_PLUGIN_LIST=""
ENV MOODLE_PLUGIN_LIST=${ARG_MOODLE_PLUGIN_LIST}
RUN if [ -n "${MOODLE_PLUGIN_LIST}" ]; then /usr/libexec/moodle/install-plugin-list -p "${MOODLE_PLUGIN_LIST}"; fi && \
    rm -rf /tmp/moodle-plugins
```
Example of build using `Dockerfile.plugins`:
```
# Build
docker buildx build . -t my_moodle_image:my_tag \
    -f Dockerfile.plugins \
    --build-arg ARG_MOODLE_PLUGIN_LIST='mod_attendance mod_checklist mod_customcert block_checklist gradeexport_checklist'
```
## Credits
- Plugin installation adopted from [Krestomatio](https://github.com/krestomatio/container_builder/tree/master/moodle)