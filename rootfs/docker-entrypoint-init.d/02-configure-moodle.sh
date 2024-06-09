#!/bin/sh
#
# Moodle configuration script
#
set -eo pipefail

config_file="${WEB_PATH}"/config.php
cfg_file="${WEB_PATH}"/admin/cli/cfg.php
php_cmd="php -d max_input_vars=10000" #TODO
cfg_cmd="$php_cmd $cfg_file" #TODO: replacing: "$php_cmd" "$cfg_file"

#
# Available functions
#

# Function to update or add a configuration value
update_or_add_config_value() {
    local key
    key=$(echo "$1" | sed 's|\[|\\[|g' | sed 's|\]|\\]|g' | sed 's|\/|\\/|g')  # The configuration key (e.g., $CFG->wwwroot), need to escape special characters for grep and sed
    local value
    value="$2"  # The new value for the configuration key
    local noquote
    noquote="$3" # Avoid adding quote

    if [ -z "$value" ]; then
        # If value is empty, remove the line with the key if it exists
        echo "Removed $key from config.php"
        sed -i "/$key/d" "$config_file"
        return
    fi

    if [ "$value" = 'true' ] || [ "$value" = 'false' ] || [ -n "$noquote" ]; then
        # Handle boolean values without quotes
        quote=''
    else
        # Other values get single-quoted
        quote="'"
    fi

    if grep -q "$key" "$config_file"; then
        # If the key exists, replace its value
        echo "Updated $key in config.php" #TODO: do not update if no change
        sed -i "s|\($key\s*=\s*\)[^;]*;|\1$quote$value$quote;|g" "$config_file"
    else
        # If the key does not exist, add it before "require_once"
        echo "Added $key in config.php"
        sed -i "/require_once/i $key\t= $quote$value$quote;" "$config_file"
    fi
}

# Function to check the availability of a database
check_db_availability() {
    local db_host="$1"
    local db_port="$2"
    local db_name="$3"

    echo "Waiting for $db_host:$db_port to be ready..."
    while ! nc -w 1 "$db_host" "$db_port"; do
        # Show some progress
        printf '.'
        sleep 1
    done
    printf "\n\nGreat, $db_host is ready!"
}

# Function to generate config.php file
generate_config_file() {
    echo "Generating config.php file..."
    ENV_VAR='var' "$php_cmd" "${WEB_PATH}"/admin/cli/install.php \
        --lang="$MOODLE_LANGUAGE" \
        --wwwroot="$SITE_URL" \
        --dataroot="/var/www/moodledata/" \
        --dbtype="$DB_TYPE" \
        --dbhost="$DB_HOST" \
        --dbname="$DB_NAME" \
        --dbuser="$DB_USER" \
        --dbpass="$DB_PASS" \
        --dbport="$DB_PORT" \
        --prefix="$DB_PREFIX" \
        --fullname="$MOODLE_SITENAME" \
        --shortname="$MOODLE_SHORTNAME" \
        --adminuser="$MOODLE_USERNAME" \
        --adminpass="$MOODLE_PASSWORD" \
        --adminemail="$MOODLE_EMAIL" \
        --non-interactive \
        --agree-license \
        --skip-database \
        --allow-unstable
}

# Function to install the database
install_database() {
    echo "Installing database..."
    "$php_cmd" "${WEB_PATH}"/admin/cli/install_database.php \
        --lang="$MOODLE_LANGUAGE" \
        --adminuser="$MOODLE_USERNAME" \
        --adminpass="$MOODLE_PASSWORD" \
        --adminemail="$MOODLE_EMAIL" \
        --fullname="$MOODLE_SITENAME" \
        --shortname="$MOODLE_SHORTNAME" \
        --agree-license
}

# Function to set extra database settings
set_extra_db_settings() {
    echo "Setting database settings in config.php file..."
    if [ -n "$DB_FETCHBUFFERSIZE" ]; then
        update_or_add_config_value "\$CFG->dboptions['fetchbuffersize']" "$DB_FETCHBUFFERSIZE"
    fi
    if [ "$DB_DBHANDLEOPTIONS" = 'true' ]; then
        update_or_add_config_value "\$CFG->dboptions['dbhandlesoptions']" 'true'
    fi
    if [ -n "$DB_HOST_REPLICA" ]; then
        if [ -n "$DB_USER_REPLICA" ] && [ -n "$DB_PASS_REPLICA" ] && [ -n "$DB_PORT_REPLICA" ]; then
            update_or_add_config_value "\$CFG->dboptions['readonly']" "[ 'instance' => [ 'dbhost' => '$DB_HOST_REPLICA', 'dbport' => '$DB_PORT_REPLICA', 'dbuser' => '$DB_USER_REPLICA', 'dbpass' => '$DB_PASS_REPLICA' ] ]"
        else
            update_or_add_config_value "\$CFG->dboptions['readonly']" "[ 'instance' => [ '$DB_HOST_REPLICA' ] ]"
        fi
    fi
}

# Function to upgrade config.php
upgrade_config_file() {
    echo "Upgrading config.php..."
    update_or_add_config_value "\$CFG->wwwroot" "$SITE_URL"
    update_or_add_config_value "\$CFG->dbtype" "$DB_TYPE"
    update_or_add_config_value "\$CFG->dbhost" "$DB_HOST"
    update_or_add_config_value "\$CFG->dbname" "$DB_NAME"
    update_or_add_config_value "\$CFG->dbuser" "$DB_USER"
    update_or_add_config_value "\$CFG->dbpass" "$DB_PASS"
    update_or_add_config_value "\$CFG->prefix" "$DB_PREFIX"
    update_or_add_config_value "\$CFG->reverseproxy" "$REVERSEPROXY"
    update_or_add_config_value "\$CFG->sslproxy" "$SSLPROXY"
    update_or_add_config_value "\$CFG->preventexecpath" "true"
    
    # Avoid cron failure by forcing to use database as lock factory
    # https://moodle.org/mod/forum/discuss.php?d=328300#p1320902
    # shellcheck disable=SC2016
    update_or_add_config_value "\$CFG->lock_factory" '\\\\core\\\\lock\\\\db_record_lock_factory'
}

# Function to configure Moodle settings via CLI
configure_moodle_settings() {
    echo "Configuring settings..."
    "$cfg_cmd" --name=pathtophp --set=/usr/bin/php
    "$cfg_cmd" --name=pathtodu --set=/usr/bin/du
    "$cfg_cmd" --name=enableblogs --set=0
    "$cfg_cmd" --name=smtphosts --set="$SMTP_HOST:$SMTP_PORT"
    "$cfg_cmd" --name=smtpuser --set="$SMTP_USER"
    "$cfg_cmd" --name=smtppass --set="$SMTP_PASSWORD"
    "$cfg_cmd" --name=smtpsecure --set="$SMTP_PROTOCOL"
    "$cfg_cmd" --name=noreplyaddress --set="$MOODLE_MAIL_NOREPLY_ADDRESS"
    "$cfg_cmd" --name=emailsubjectprefix --set="$MOODLE_MAIL_PREFIX"

    if [ "$DISABLE_WEB_INSTALL_PLUGIN" = 'true' ]; then
        "$cfg_cmd" --name=disableupdateautodeploy --set=1
    else
        "$cfg_cmd" --name=disableupdateautodeploy --set=0
    fi

    # Check if DEBUG is set to true
    if [ "${DEBUG:-false}" = "true" ]; then
        echo "Enabling debug mode..."
        php "$cfg_file" --name=debug --set=32767 # DEVELOPER
        php "$cfg_file" --name=debugdisplay --set=1
    else
        echo "Disabling debug mode..."
        php "$cfg_file" --name=debug --set=0 # NONE
        php "$cfg_file" --name=debugdisplay --set=0
    fi
}

# Function to perform some final configurations
final_configurations() {
    echo "Performing final setup..."
    # Avoid writing the config file
    chmod 440 "$config_file"

    # Fix publicpaths check to point to the internal container on port 8080
    sed -i 's/wwwroot/wwwroot\ \. \"\:8080\"/g' lib/classes/check/environment/publicpaths.php
}

# Function to upgrade Moodle
upgrade_moodle() {
    # Check current moodle maintenance status and keep in maintenance mode in case of manual enablement of it
    # This is also useful when deploying multiple moodle instances in a cluster using shared storage,
    # in order to avoid interruption to users while moodle restart
    echo "Checking maintenance status..."
    START_IN_MAINT_MODE=false
    MAINT_STATUS=$("$php_cmd" "${WEB_PATH}"/admin/cli/maintenance.php | sed 's/^==.*==//g' | sed '/^$/d')
    if [ "$MAINT_STATUS" = "$MAINT_STATUS_KEYWORD" ]; then
        echo "Maintenance mode will be kept enabled"
        START_IN_MAINT_MODE=true
    fi
    echo "Upgrading moodle..."
    "$php_cmd" "${WEB_PATH}"/admin/cli/maintenance.php --enable
    if [ "${ENABLE_GIT_CLONE}" = 'true' ]; then
        if [ -z "$UPDATE_MOODLE_CODE" ] || [ "$UPDATE_MOODLE_CODE" = true ]; then
            echo "Checking moodle code version..."
            git -C "${WEB_PATH}" fetch origin "$MODOLE_GIT_BRANCH" --depth=1 && git -C "${WEB_PATH}" checkout FETCH_HEAD -B "$MODOLE_GIT_BRANCH"
        fi
    fi
    "$php_cmd" "${WEB_PATH}"/admin/cli/upgrade.php --non-interactive --allow-unstable
    if [ $START_IN_MAINT_MODE = false ]; then
        "$php_cmd" "${WEB_PATH}"/admin/cli/maintenance.php --disable
    else
        echo "Started in maintenance mode, requires manual disable the maintenance mode"
    fi
}

# Function to verify the source code integrity
# - Check if new volume is mounted that Moodle code directory will be empty
# - Download the Moodle source code in the same way as specified in DockerFile
verify_moodle_source() {
    echo "Checking source code existence..."
    # shellcheck disable=SC2010
    if [ -z "$(ls -A "${WEB_PATH}" | grep -v 'config.php')" ]; then
        echo "Downloading Moodle source codes..."
        /usr/libexec/moodle/download-moodle-code
        if [ ! -f "${WEB_PATH}"/admin/cli/isinstalled.php ]; then
            echo "Copying isinstalled.php..."
            cp -p /usr/libexec/moodle/isinstalled.php "${WEB_PATH}"/admin/cli/
        fi
    fi 
}

# Function to change session caching settings
config_session_cache() {
    if [ -z "$SESSION_CACHE_TYPE" ]; then
        echo "Using default file session store"
    else
        echo "Using $SESSION_CACHE_TYPE as session store"
        case $SESSION_CACHE_TYPE in
            memcached)
                # Check that the cache store is available
                echo "Waiting for $SESSION_CACHE_HOST:$SESSION_CACHE_PORT to be ready..."
                while ! nc -w 1 "$SESSION_CACHE_HOST" "$SESSION_CACHE_PORT"; do
                    # Show some progress
                    printf '.';
                    sleep 1;
                done
                echo "$SESSION_CACHE_HOST is ready"
                # Give it another 3 seconds.
                sleep 3;
                if [ -n "$SESSION_CACHE_HOST" ] && [ -n "$SESSION_CACHE_PORT" ] ; then
                    "$cfg_cmd" --name=session_handler_class --set='\core\session\memcached'
                    "$cfg_cmd" --name=session_memcached_save_path --set="$SESSION_CACHE_HOST:$SESSION_CACHE_PORT"
                    "$cfg_cmd" --name=session_memcached_prefix --set="$SESSION_CACHE_PREFIX.memc.sess.key."
                    "$cfg_cmd" --name=session_memcached_acquire_lock_timeout --set=120
                    "$cfg_cmd" --name=session_memcached_lock_expire --set=7200
                fi
                ;;
            redis)
                # Check that the cache store is available
                echo "Waiting for $SESSION_CACHE_HOST:$SESSION_CACHE_PORT to be ready..."
                while ! nc -w 1 "$SESSION_CACHE_HOST" "$SESSION_CACHE_PORT"; do
                    # Show some progress
                    printf '.';
                    sleep 1;
                done
                echo "$SESSION_CACHE_HOST is ready"
                # Give it another 3 seconds.
                sleep 3;
                if [ -n "$SESSION_CACHE_HOST" ] && [ -n "$SESSION_CACHE_PORT" ] ; then
                    "$cfg_cmd" --name=session_handler_class --set='\core\session\redis'
                    "$cfg_cmd" --name=session_redis_host --set="$SESSION_CACHE_HOST"
                    "$cfg_cmd" --name=session_redis_port --set="$SESSION_CACHE_PORT"
                    if [ -n "$SESSION_CACHE_AUTH" ] ; then
                        "$cfg_cmd" --name=session_redis_auth --set="$SESSION_CACHE_AUTH"
                    fi
                    "$cfg_cmd" --name=session_redis_prefix --set="$SESSION_CACHE_PREFIX"
                    "$cfg_cmd" --name=session_redis_acquire_lock_timeout --set=120
                    "$cfg_cmd" --name=session_redis_lock_expire --set=7200
                    "$cfg_cmd" --name=session_redis_serializer_use_igbinary --set='true'
                fi
                ;;
            database)
                "$cfg_cmd" --name=session_handler_class --set='\core\session\database'
                "$cfg_cmd" --name=session_database_acquire_lock_timeout --set=120
                ;;
        esac
    fi
}

config_file_serving() {
    echo "Configuring file serving..."
    # Offload the file serving from PHP process
    update_or_add_config_value "\$CFG->xsendfile" "X-Accel-Redirect"
    update_or_add_config_value "\$CFG->xsendfilealiases['/dataroot/']" "\$CFG->dataroot" "noquote"
    
    if [ -n "$LOCAL_CACHE_DIRECTORY" ]; then
        if [ ! -d "$LOCAL_CACHE_DIRECTORY" ]; then
            echo "Creating $LOCAL_CACHE_DIRECTORY for localcachedir..."
            mkdir -p "$LOCAL_CACHE_DIRECTORY"
        fi
        update_or_add_config_value "\$CFG->localcachedir" "$LOCAL_CACHE_DIRECTORY"
        update_or_add_config_value "\$CFG->xsendfilealiases['/localcachedir/']" "$LOCAL_CACHE_DIRECTORY"
        cat << EOL >> /etc/nginx/conf.d/default/server/moodle.conf
    location ~ ^/localcachedir/(.*)$ {
        internal;
        alias $LOCAL_CACHE_DIRECTORY/\$1;
    }
EOL
        echo "Set $LOCAL_CACHE_DIRECTORY as localcachedir"
    fi
}

#
# Main function
#

# Check the availability of the primary database
check_db_availability "$DB_HOST" "$DB_PORT"

# Check the availability of the database replica if specified
if [ -n "$DB_HOST_REPLICA" ]; then
    check_db_availability "$DB_HOST_REPLICA" "${DB_PORT_REPLICA:-$DB_PORT}"
fi

# Give it another 3 seconds.
sleep 3;

# Verify the source code integrity
verify_moodle_source

# Generate config.php file if it doesn't exist
if [ ! -f "$config_file" ]; then
    generate_config_file
    set_extra_db_settings
fi

# Upgrade config.php file
upgrade_config_file

# Check if the database is already installed
if "$php_cmd" "${WEB_PATH}"/admin/cli/isinstalled.php ; then
    install_database
fi

# Post installation configurations
configure_moodle_settings
config_session_cache
config_file_serving

# Upgrade moodle if needed
if [ -z "$AUTO_UPDATE_MOODLE" ] || [ "$AUTO_UPDATE_MOODLE" = true ]; then
    upgrade_moodle
else
    echo "Skipped auto update of Moodle"
fi

final_configurations