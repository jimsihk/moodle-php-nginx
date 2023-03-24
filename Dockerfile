ARG ARCH=
FROM ${ARCH}jimsihk/alpine-php-nginx:81.17.0

LABEL Maintainer="99048231+jimsihk@users.noreply.github.com" \
      Description="Lightweight Moodle container with NGINX & PHP-FPM based on Alpine Linux."

# renovate: datasource=repology depName=alpine_3_17/dcron versioning=loose
ARG DCRON_VERSION="=4.5-r8"
# renovate: datasource=repology depName=alpine_3_17/libcap versioning=loose
ARG LIBCAP_VERSION="=2.66-r0"
# renovate: datasource=repology depName=alpine_3_17/git versioning=loose
ARG GIT_VERSION="=2.38.4-r1"
# renovate: datasource=repology depName=alpine_3_16/bash versioning=loose
ARG BASH_VERSION="=5.2.15-r0"

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
ARG ARG_MODOLE_GIT_BRANCH='MOODLE_401_STABLE'
# renovate: datasource=git-refs depName=https://github.com/moodle/moodle branch=MOODLE_401_STABLE
ARG ARG_MODOLE_GIT_COMMIT='5898c3e5dd834d50cd7f6cda30818f5614b09b2e'
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
    DISABLE_WEB_INSTALL_PLUGIN=false

# Install from Git for easier upgrade in the future
# - Using temporary storage to store the Git repo and copy back to working directory 
#   to avoid deteched head and failure due to files exist in the directory
# - Git depth is set to 1 and and single branch to reduce docker size while keeping
#   the functionality of git pull from source
ARG TEMP_MOODLE_PATH='/tmp/moodle'
RUN if [ -d /tmp/moodle ]; then rm -rf /tmp/moodle; fi \
    && git clone "${MOODLE_GIT_URL}" --branch "${MODOLE_GIT_BRANCH}" --single-branch --depth 1 ${TEMP_MOODLE_PATH}/ \
    && if [ -f ${TEMP_MOODLE_PATH}/Gruntfile.js ]; then rm ${TEMP_MOODLE_PATH}/Gruntfile.js; fi \
    && if [ -f ${TEMP_MOODLE_PATH}/config-dist.php ]; then rm ${TEMP_MOODLE_PATH}/config-dist.php; fi \
    && cp -paR ${TEMP_MOODLE_PATH}/. ${WEB_PATH}/ \
    && rm -rf ${TEMP_MOODLE_PATH}
RUN /usr/libexec/moodle/check-moodle-version "${MOODLE_GIT_COMMIT}"

# Install plugin for Redis Sentinel as cache store
ARG REDISSENTINEL_PLUGIN_GIT_URL='https://github.com/catalyst/moodle-cachestore_redissentinel.git'
ARG REDISSENTINEL_PLUGIN_GIT_BRANCH='master'
# renovate: datasource=git-refs depName=https://github.com/catalyst/moodle-cachestore_redissentinel branch=master
ARG REDISSENTINEL_PLUGIN_GIT_COMMIT='b495e8f36a81fd1a2a414e34a978da879c473f31'
RUN git clone "${REDISSENTINEL_PLUGIN_GIT_URL}" --branch "${REDISSENTINEL_PLUGIN_GIT_BRANCH}" --depth 1 ${WEB_PATH}/cache/stores/redissentinel/
RUN /usr/libexec/check-git-commit "${WEB_PATH}/cache/stores/redissentinel/" "${REDISSENTINEL_PLUGIN_GIT_COMMIT}"

# Install additional plugins (a space/comma separated arguement), if any
# Reference: https://github.com/krestomatio/container_builder/tree/master/moodle#moodle-plugins
ARG ARG_MOODLE_PLUGIN_LIST=""
ENV MOODLE_PLUGIN_LIST=${ARG_MOODLE_PLUGIN_LIST}
RUN if [ -n "${MOODLE_PLUGIN_LIST}" ]; then /usr/libexec/moodle/install-plugin-list -p "${MOODLE_PLUGIN_LIST}"; fi \
    && rm -rf /tmp/moodle-plugins
