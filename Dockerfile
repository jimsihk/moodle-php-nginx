ARG ARCH=quay.io/
FROM ${ARCH}jimsihk/alpine-php-nginx:81.19.2

LABEL Maintainer="99048231+jimsihk@users.noreply.github.com" \
      Description="Lightweight Moodle container with NGINX & PHP-FPM based on Alpine Linux."

# renovate: datasource=repology depName=alpine_3_18/dcron versioning=loose
ARG DCRON_VERSION="=4.5-r9"
# renovate: datasource=repology depName=alpine_3_18/libcap versioning=loose
ARG LIBCAP_VERSION="=2.69-r0"
# renovate: datasource=repology depName=alpine_3_18/git versioning=loose
ARG GIT_VERSION="=2.40.1-r0"
# renovate: datasource=repology depName=alpine_3_18/bash versioning=loose
ARG BASH_VERSION="=5.2.15-r3"

ARG WEB_PATH='/var/www/html'

USER root
COPY --chown=nobody rootfs/ /

# crond needs root, so install dcron and cap package and set the capabilities
# on dcron binary https://github.com/inter169/systs/blob/master/alpine/crond/README.md
RUN apk add --no-cache \
        dcron${DCRON_VERSION} \
        libcap${LIBCAP_VERSION} \
        git${GIT_VERSION} \
        bash${BASH_VERSION} \
    && chown nobody:nobody /usr/sbin/crond \
    && setcap cap_setgid=ep /usr/sbin/crond \
    # Clean up unused files from base image
    && rm ${WEB_PATH}/index.php ${WEB_PATH}/test.html

USER nobody

# Change MOODLE_XX_STABLE for new versions
ARG ARG_MOODLE_GIT_URL='https://github.com/moodle/moodle.git'
ARG ARG_MODOLE_GIT_BRANCH='MOODLE_402_STABLE'
# renovate: datasource=git-refs depName=https://github.com/moodle/moodle branch=MOODLE_402_STABLE
ARG ARG_MODOLE_GIT_COMMIT='4781b41631664d3c5e7e94cfcc279b2af81e4dd1'
ENV MOODLE_GIT_URL=${ARG_MOODLE_GIT_URL} \
    MODOLE_GIT_BRANCH=${ARG_MODOLE_GIT_BRANCH} \
    MOODLE_GIT_COMMIT=${ARG_MODOLE_GIT_COMMIT} \
    LANG=en_US.UTF-8 \
    LANGUAGE=en_US:en \
    SITE_URL=http://localhost \
    DB_TYPE=pgsql \
    DB_HOST=postgres \
    DB_PORT=5432 \
    DB_NAME=moodle \
    DB_USER=moodle \
    DB_PASS=moodle \
    DB_PREFIX=mdl_ \
    DB_DBHANDLEOPTIONS=false \
    SSLPROXY=false \
    MOODLE_EMAIL=user@example.com \
    MOODLE_LANGUAGE=en \
    MOODLE_SITENAME=New-Site \
    MOODLE_SHORTNAME=moodle \
    MOODLE_USERNAME=moodleuser \
    MOODLE_PASSWORD=PLEASE_CHANGEME \
    SMTP_HOST=smtp.gmail.com \
    SMTP_PORT=587 \
    SMTP_USER=your_email@gmail.com \
    SMTP_PASSWORD=your_password  \
    SMTP_PROTOCOL=tls \
    MOODLE_MAIL_NOREPLY_ADDRESS=noreply@localhost \
    MOODLE_MAIL_PREFIX=[moodle] \
    client_max_body_size=50M \
    post_max_size=50M \
    upload_max_filesize=50M \
    max_input_vars=5000 \
    SESSION_CACHE_PREFIX=mdl \
    AUTO_UPDATE_MOODLE=true \
    UPGRADE_MOODLE_CODE=true \
    DISABLE_WEB_INSTALL_PLUGIN=false \
    MAINT_STATUS_KEYWORD='Status: enabled'

ARG TEMP_MOODLE_PATH='/tmp/moodle'

ARG REDISSENTINEL_PLUGIN_GIT_URL='https://github.com/catalyst/moodle-cachestore_redissentinel.git'
ARG REDISSENTINEL_PLUGIN_GIT_BRANCH='master'
# renovate: datasource=git-refs depName=https://github.com/catalyst/moodle-cachestore_redissentinel branch=master
ARG REDISSENTINEL_PLUGIN_GIT_COMMIT='b495e8f36a81fd1a2a414e34a978da879c473f31'

ARG MEMCACHED_PLUGIN_GIT_URL='https://github.com/moodlehq/moodle-cachestore_memcached'
ARG MEMCACHED_PLUGIN_GIT_BRANCH='master'
# renovate: datasource=git-refs depName=https://github.com/moodlehq/moodle-cachestore_memcached branch=master
ARG MEMCACHED_PLUGIN_GIT_COMMIT='db68d31ab5856cb55210478fdd452dc0cd6c6d05'

ARG ARG_MOODLE_PLUGIN_LIST=""
ENV MOODLE_PLUGIN_LIST=${ARG_MOODLE_PLUGIN_LIST}

# Install from Git for easier upgrade in the future
# - Using temporary storage to store the Git repo and copy back to working directory 
#   to avoid deteched head and failure due to files exist in the directory
# - Git depth is set to 1 and and single branch to reduce docker size while keeping
#   the functionality of git pull from source
RUN if [ -d /tmp/moodle ]; then rm -rf /tmp/moodle; fi \
    && git clone "${MOODLE_GIT_URL}" --branch "${MODOLE_GIT_BRANCH}" --single-branch --depth 1 ${TEMP_MOODLE_PATH}/ \
    && if [ -f ${TEMP_MOODLE_PATH}/Gruntfile.js ]; then rm ${TEMP_MOODLE_PATH}/Gruntfile.js; fi \
    && if [ -f ${TEMP_MOODLE_PATH}/config-dist.php ]; then rm ${TEMP_MOODLE_PATH}/config-dist.php; fi \
    && cp -paR ${TEMP_MOODLE_PATH}/. ${WEB_PATH}/ \
    && rm -rf ${TEMP_MOODLE_PATH} \
    && /usr/libexec/moodle/check-moodle-version "${MOODLE_GIT_COMMIT}" \
# Install plugin for Redis Sentinel cache store \
# Reference: https://github.com/catalyst/moodle-cachestore_redissentinel \
    && /usr/libexec/moodle/install-git-plugin \
          "${REDISSENTINEL_PLUGIN_GIT_URL}"  \
          "${REDISSENTINEL_PLUGIN_GIT_BRANCH}" \
          "${REDISSENTINEL_PLUGIN_GIT_COMMIT}" \
          "${WEB_PATH}/cache/stores/redissentinel/" \
# Install plugin for memcached cache store which was removed from Moodle core since 4.2
# Reference: https://tracker.moodle.org/browse/MDL-77161 \
    && /usr/libexec/moodle/install-git-plugin \
          "${MEMCACHED_PLUGIN_GIT_URL}" \
          "${MEMCACHED_PLUGIN_GIT_BRANCH}" \
          "${MEMCACHED_PLUGIN_GIT_COMMIT}" \
          "${WEB_PATH}/cache/stores/memcached/" \
# Install additional plugins (a space/comma separated argument), if any
# Reference: https://github.com/krestomatio/container_builder/tree/master/moodle#moodle-plugins
    && if [ -n "${MOODLE_PLUGIN_LIST}" ]; then /usr/libexec/moodle/install-plugin-list -p "${MOODLE_PLUGIN_LIST}"; fi \
    && rm -rf /tmp/moodle-plugins
