#!/bin/sh
#
# Moodle configuration script
#
set -eo pipefail

# Check that the database is available
echo "Waiting for $DB_HOST:$DB_PORT to be ready"
while ! nc -w 1 $DB_HOST $DB_PORT; do
    # Show some progress
    echo -n '.';
    sleep 1;
done
echo "$DB_HOST is ready"
# Give it another 3 seconds.
sleep 3;


# Check if the config.php file exists
if [ ! -f /var/www/html/config.php ]; then

    echo "Generating config.php file..."
    ENV_VAR='var' php -d max_input_vars=10000 /var/www/html/admin/cli/install.php \
        --lang=$MOODLE_LANGUAGE \
        --wwwroot=$SITE_URL \
        --dataroot=/var/www/moodledata/ \
        --dbtype=$DB_TYPE \
        --dbhost=$DB_HOST \
        --dbname=$DB_NAME \
        --dbuser=$DB_USER \
        --dbpass=$DB_PASS \
        --dbport=$DB_PORT \
        --prefix=$DB_PREFIX \
        --fullname=Dockerized_Moodle \
        --shortname=moodle \
        --adminuser=$MOODLE_USERNAME \
        --adminpass=$MOODLE_PASSWORD \
        --adminemail=$MOODLE_EMAIL \
        --non-interactive \
        --agree-license \
        --skip-database \
        --allow-unstable

    # Offload the file serving from PHP process
    sed -i '/require_once/i $CFG->xsendfile = '\''X-Accel-Redirect'\'';' /var/www/html/config.php
    sed -i '/require_once/i $CFG->xsendfilealiases = array('\''\/dataroot\/'\'' => $CFG->dataroot);' /var/www/html/config.php

    if [ "$SSLPROXY" = 'true' ]; then
        sed -i '/require_once/i $CFG->sslproxy=true;' /var/www/html/config.php
    fi

    # Avoid allowing executable paths to be set via the Admin GUI
    echo "\$CFG->preventexecpath = true;" >> /var/www/html/config.php

fi

# Function to change session caching settings
config_session_cache() {
  if [ -z $SESSION_CACHE_TYPE ]; then
    echo "Using default file session store"
  else
    echo "Using $SESSION_CACHE_TYPE as session store"
    case $SESSION_CACHE_TYPE in
        memcached)
            # Check that the cache store is available
            echo "Waiting for $SESSION_CACHE_HOST:$SESSION_CACHE_PORT to be ready..."
            while ! nc -w 1 $SESSION_CACHE_HOST $SESSION_CACHE_PORT; do
                # Show some progress
                echo -n '.';
                sleep 1;
            done
            echo "$SESSION_CACHE_HOST is ready"
            # Give it another 3 seconds.
            sleep 3;
            if [ ! -z $SESSION_CACHE_HOST ] && [ ! -z $SESSION_CACHE_PORT ] ; then
                php -d max_input_vars=10000 /var/www/html/admin/cli/cfg.php --name=session_handler_class --set='\core\session\memcached'
                php -d max_input_vars=10000 /var/www/html/admin/cli/cfg.php --name=session_memcached_save_path --set="$SESSION_CACHE_HOST:$SESSION_CACHE_PORT"
                php -d max_input_vars=10000 /var/www/html/admin/cli/cfg.php --name=session_memcached_prefix --set="$SESSION_CACHE_PREFIX.memc.sess.key."
                php -d max_input_vars=10000 /var/www/html/admin/cli/cfg.php --name=session_memcached_acquire_lock_timeout --set=120
                php -d max_input_vars=10000 /var/www/html/admin/cli/cfg.php --name=session_memcached_lock_expire --set=7200
            fi
            ;;
        database)
            php -d max_input_vars=10000 /var/www/html/admin/cli/cfg.php --name=session_handler_class --set='\core\session\database'
            php -d max_input_vars=10000 /var/www/html/admin/cli/cfg.php --name=session_database_acquire_lock_timeout --set=120
            ;;
    esac
  fi
}

# Check if the database is already installed
if php -d max_input_vars=10000 /var/www/html/admin/cli/isinstalled.php ; then

    echo "Installing database..."
    php -d max_input_vars=10000 /var/www/html/admin/cli/install_database.php \
        --lang=$MOODLE_LANGUAGE \
        --adminuser=$MOODLE_USERNAME \
        --adminpass=$MOODLE_PASSWORD \
        --adminemail=$MOODLE_EMAIL \
        --fullname=Dockerized_Moodle \
        --shortname=moodle \
        --agree-license

    echo "Configuring settings..."

    # php -d max_input_vars=10000 /var/www/html/admin/cli/cfg.php --name=slasharguments --set=0
    php -d max_input_vars=10000 /var/www/html/admin/cli/cfg.php --name=pathtophp --set=/usr/bin/php
    php -d max_input_vars=10000 /var/www/html/admin/cli/cfg.php --name=pathtodu --set=/usr/bin/du
    # php -d max_input_vars=10000 /var/www/html/admin/cli/cfg.php --name=aspellpath --set=/usr/bin/aspell
    # php -d max_input_vars=10000 /var/www/html/admin/cli/cfg.php --name=pathtodot --set=/usr/bin/dot
    # php -d max_input_vars=10000 /var/www/html/admin/cli/cfg.php --name=pathtogs --set=/usr/bin/gs
    # php -d max_input_vars=10000 /var/www/html/admin/cli/cfg.php --name=pathtopython --set=/usr/bin/python3
    php -d max_input_vars=10000 /var/www/html/admin/cli/cfg.php --name=enableblogs --set=0


    php -d max_input_vars=10000 /var/www/html/admin/cli/cfg.php --name=smtphosts --set=$SMTP_HOST:$SMTP_PORT
    php -d max_input_vars=10000 /var/www/html/admin/cli/cfg.php --name=smtpuser --set=$SMTP_USER
    php -d max_input_vars=10000 /var/www/html/admin/cli/cfg.php --name=smtppass --set=$SMTP_PASSWORD
    php -d max_input_vars=10000 /var/www/html/admin/cli/cfg.php --name=smtpsecure --set=$SMTP_PROTOCOL
    php -d max_input_vars=10000 /var/www/html/admin/cli/cfg.php --name=noreplyaddress --set=$MOODLE_MAIL_NOREPLY_ADDRESS
    php -d max_input_vars=10000 /var/www/html/admin/cli/cfg.php --name=emailsubjectprefix --set=$MOODLE_MAIL_PREFIX
    
    # Set session cache store
    config_session_cache
    
    # Remove .swf (flash) plugin for security reasons DISABLED BECAUSE IS REQUIRED
    #php -d max_input_vars=10000 /var/www/html/admin/cli/uninstall_plugins.php --plugins=media_swf --run

    # Avoid writing the config file
    chmod 444 config.php

    # Fix publicpaths check to point to the internal container on port 8080
    sed -i 's/wwwroot/wwwroot\ \. \"\:8080\"/g' lib/classes/check/environment/publicpaths.php

else
    if [ -z AUTO_UPDATE_MOODLE ] || [ $AUTO_UPDATE_MOODLE = true ]; then
      # Check current moodle maintenance status and keep in maintenance mode in case of manual enablement of it
      # This is also useful when deploying multiple moodle instances in a cluster using shared storage,
      # in order to avoid interruption to users while moodle restart
      echo "Checking maintenance status..."
      START_IN_MAINT_MODE=false
      MAINT_STATUS=$(php -d max_input_vars=10000 /var/www/html/admin/cli/maintenance.php | sed 's/^==.*==//g' | sed '/^$/d')
      if [ "$MAINT_STATUS" = 'Status: enabled' ]; then
          echo "Maintenance mode will be kept enabled"
          START_IN_MAINT_MODE=true
      fi
      echo "Upgrading moodle..."
      php -d max_input_vars=10000 /var/www/html/admin/cli/maintenance.php --enable
      git -C /var/www/html pull
      php -d max_input_vars=10000 /var/www/html/admin/cli/upgrade.php --non-interactive --allow-unstable
      # Set session cache store
      config_session_cache
      if [ $START_IN_MAINT_MODE = false ]; then
          php -d max_input_vars=10000 /var/www/html/admin/cli/maintenance.php --disable
      else
          echo "Started in maintenance mode, requires manual disable the maintenance mode"
      fi
    else
      echo "Skipped auto update of Moodle"
    fi
fi
