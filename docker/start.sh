#!/usr/bin/env bash
set -e

role=${CONTAINER_ROLE:-app}
env=${APP_ENV:-production}

if [ "$env" != "local" ]; then
    echo "Caching configuration..."
    (cd /var/www/html && php artisan config:cache && php artisan route:cache && php artisan view:cache)
fi

if [ "$role" = "app" ]; then

    exec php-fpm

elif [ "$role" = "scheduler" ]; then

    echo "Queue role"
    while [ true ]
    do
      php /var/www/artisan schedule:run --verbose --no-interaction &
      sleep 60
    done

elif [ "$role" = "queue" ]; then

    echo "Running the queue..."
    /usr/bin/supervisord -n -c /etc/supervisor/supervisord.conf
else
    echo "Could not match the container role \"$role\""
    exit 1
fi
