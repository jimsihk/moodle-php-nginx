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

    echo "Using $CACHE_TYPE as cache"
    case $CACHE_TYPE in
        memcached)
            # Check that the cache store is available
            echo "Waiting for $CACHE_HOST:$CACHE_PORT to be ready"
            while ! nc -w 1 $CACHE_HOST $CACHE_PORT; do
                # Show some progress
                echo -n '.';
                sleep 1;
            done
            echo "$CACHE_HOST is ready"
            # Give it another 3 seconds.
            sleep 3;
            if [ ! -z $CACHE_HOST ] && [ ! -z $CACHE_PORT ] ; then
                sed -i '/require_once/i $CFG->session_handler_class = '\''\\core\\session\\memcached'\'';' /var/www/html/config.php
                sed -i "/require_once/i \$CFG->session_memcached_save_path = '$CACHE_HOST:$CACHE_PORT';" /var/www/html/config.php
                sed -i "/require_once/i \$CFG->session_memcached_prefix = '$CACHE_PREFIX.memc.sess.key.';" /var/www/html/config.php
                sed -i '/require_once/i $CFG->session_memcached_acquire_lock_timeout = 120;' /var/www/html/config.php
                sed -i '/require_once/i $CFG->session_memcached_lock_expire = 7200;' /var/www/html/config.php
            fi
            ;;
        database)
            sed -i '/require_once/i $CFG->session_handler_class = '\''\\core\\session\\database'\'';' /var/www/html/config.php
            sed -i '/require_once/i $CFG->session_database_acquire_lock_timeout = 120;' /var/www/html/config.php
            ;;
    esac

    if [ "$SSLPROXY" = 'true' ]; then
        sed -i '/require_once/i $CFG->sslproxy=true;' /var/www/html/config.php
    fi

    # Avoid allowing executable paths to be set via the Admin GUI
    echo "\$CFG->preventexecpath = true;" >> /var/www/html/config.php

fi

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
    
    # Remove .swf (flash) plugin for security reasons DISABLED BECAUSE IS REQUIRED
    #php -d max_input_vars=10000 /var/www/html/admin/cli/uninstall_plugins.php --plugins=media_swf --run

    # Avoid writing the config file
    chmod 444 config.php

    # Fix publicpaths check to point to the internal container on port 8080
    sed -i 's/wwwroot/wwwroot\ \. \"\:8080\"/g' lib/classes/check/environment/publicpaths.php

else
    echo "Upgrading moodle..."
    php -d max_input_vars=10000 /var/www/html/admin/cli/maintenance.php --enable
    php -d max_input_vars=10000 /var/www/html/admin/cli/upgrade.php --non-interactive --allow-unstable
    php -d max_input_vars=10000 /var/www/html/admin/cli/maintenance.php --disable
fi
