<p align="center">
  <a href="https://dev.to/vumdao">
    <img alt="Running the Laravel Scheduler and Queue with Docker" src="https://dev-to-uploads.s3.amazonaws.com/i/12zmbwwtwdvyx6wu6vu3.png" width="500" />
  </a>
</p>
<h1 align="left">
  Running the Laravel Scheduler and Queue with Docker
</h1>

![Alt Text](https://dev-to-uploads.s3.amazonaws.com/i/xfp1y165hbygvgxqgvqj.png)

### 🚀 **[Get application code](#-Get-application-code)**
```
https://github.com/vumdao/travellist-laravel-demo
```

### 🚀 **[Setting Up the Application’s Dockerfile](#-Setting-Up-the-Application’s-Dockerfile)**
| `start.sh` |
--------------
```
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
```

| `Dockerfile` |
----------------
```
FROM php:7.4-fpm

# Arguments defined in docker-compose.yml
ARG user
ARG uid

# Install system dependencies
RUN apt-get update && apt-get install -y \
    git \
    curl \
    libpng-dev \
    libonig-dev \
    libxml2-dev \
    zip \
    unzip \
    supervisor

# Clear cache
RUN apt-get clean && rm -rf /var/lib/apt/lists/*

# Install PHP extensions
RUN docker-php-ext-install pdo_mysql mbstring exif pcntl bcmath gd
# setup redis
RUN pecl install redis \
        && docker-php-ext-enable redis

# Get latest Composer
COPY --from=composer:latest /usr/bin/composer /usr/bin/composer


# Create system user to run Composer and Artisan Commands
# RUN useradd -G www-data,root -u $uid -d /home/$user $user
# RUN mkdir -p /home/$user/.composer && \
#     chown -R $user:$user /home/$user && \
#     chown -R $user:$user /var/www/


# Set working directory
WORKDIR /var/www
ADD composer.json ./
RUN composer install --prefer-dist --no-scripts --no-autoloader --no-interaction --no-ansi --optimize-autoloader

COPY . /var/www/
VOLUME /var/www/storage /var/www/bootstrap
# Create system user to run Composer and Artisan Commands


COPY docker/start.sh /usr/local/bin/start
RUN chown -R $user: /var/www \
    && chmod u+x /usr/local/bin/start
COPY docker/supervisord.conf /etc/supervisor/supervisord.conf

# USER $user
CMD ["/usr/local/bin/start"]
```

### 🚀 **[Setting Up Nginx Configuration and Database Dump Files](#-Setting-Up-Nginx-Configuration-and-Database-Dump-Files)**
- The file will configure Nginx to listen on port 80 and use index.php as default index page. It will set the document root to /var/www/public, and then configure Nginx to use the app service on port 9000 to process *.php files.
```
$ cat docker-compose/nginx/travellist.conf
server {
    listen 80;
    index index.php index.html;
    error_log  /var/log/nginx/error.log;
    access_log /var/log/nginx/access.log;
    root /var/www/public;
    location ~ \.php$ {
        try_files $uri =404;
        fastcgi_split_path_info ^(.+\.php)(/.+)$;
        fastcgi_pass app:9000;
        fastcgi_index index.php;
        include fastcgi_params;
        fastcgi_param SCRIPT_FILENAME $document_root$fastcgi_script_name;
        fastcgi_param PATH_INFO $fastcgi_path_info;
    }
    location / {
        try_files $uri $uri/ /index.php?$query_string;
        gzip_static on;
    }
}
```

### 🚀 **[Create MySQL initialization files in order to init database at startup](#-Create-MySQL-initialization-files-in-order-to-init-database-at-startup)**
```
$ cat docker-compose/mysql/init_db.sql 
DROP TABLE IF EXISTS `places`;

CREATE TABLE `places` (
  `id` bigint(20) unsigned NOT NULL AUTO_INCREMENT,
  `name` varchar(255) COLLATE utf8mb4_unicode_ci NOT NULL,
  `visited` tinyint(1) NOT NULL DEFAULT '0',
  PRIMARY KEY (`id`)
) ENGINE=InnoDB AUTO_INCREMENT=12 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

INSERT INTO `places` (name, visited) VALUES ('Berlin',0),('Budapest',0),('Cincinnati',1),('Denver',0),('Helsinki',0),('Lisbon',0),('Moscow',1),('Nairobi',0),('Oslo',1),('Rio',0),('Tokyo',0);
```

### 🚀 **[Setting Up the Application’s `.env` File](#-Setting-Up-the-Application’s-`.env`-File)**
```
cd travellist-laravel-demo-tutorial-4.0.1
cp .env.example .env
```
- Modify `.env` to correct information

| .env |
--------
```
DB_CONNECTION=mysql
DB_HOST=db
DB_PORT=3306
DB_DATABASE=travellist
DB_USERNAME=user
DB_PASSWORD=password
```

### 🚀 **[Create `docker-compose.yaml` with support all three roles](#-Create-`docker-compose.yaml`-with-support-all-three-roles)**
- Web server `exec php-fpm`
- Scheduler runner `php /var/www/artisan schedule:run`
- Queue worker `/usr/bin/supervisord -n -c /etc/supervisor/supervisord.conf`
```
version: "3.7"
services:
  app:
    build:
      args:
        user: www-data
        uid: 1000
      context: ./
      dockerfile: Dockerfile
    image: travellist
    container_name: travellist-app
    restart: unless-stopped
    working_dir: /var/www/
    volumes:
      - ./:/var/www
      - composer_cache:/home/.sammy/.composer
    networks:
      - travellist
    environment:
      APP_ENV: local
      CONTAINER_ROLE: app

  scheduler:
    image: travellist
    container_name: travellist-scheduler
    depends_on:
      - app
    restart: unless-stopped
    working_dir: /var/www/
    volumes:
      - ./:/var/www
      - composer_cache:/home/.sammy/.composer
    networks:
      - travellist
    environment:
      APP_ENV: local
      CONTAINER_ROLE: scheduler

  queue:
    image: travellist
    container_name: travellist-queue
    depends_on:
      - app
    volumes:
      - ./:/var/www
      - composer_cache:/home/.sammy/.composer
    environment:
      APP_ENV: local
      CONTAINER_ROLE: queue
      CACHE_DRIVER: redis
      SESSION_DRIVER: redis
      QUEUE_DRIVER: redis
      REDIS_HOST: redis

  redis:
    container_name: travellist-redis
    image: redis:4-alpine
    ports:
      - 16379:6379

  db:
    image: mysql:5.7
    container_name: travellist-db
    restart: unless-stopped
    environment:
      MYSQL_DATABASE: travellist
      MYSQL_ROOT_PASSWORD: password
      MYSQL_PASSWORD: password
      MYSQL_USER: user
      SERVICE_TAGS: dev
      SERVICE_NAME: mysql
    volumes:
      - ./docker-compose/mysql:/docker-entrypoint-initdb.d
    networks:
      - travellist

  nginx:
    image: nginx:alpine
    container_name: travellist-nginx
    restart: unless-stopped
    ports:
      - "8000:80"
    volumes:
      - ./:/var/www
      - ./docker-compose/nginx:/etc/nginx/conf.d
    networks:
      - travellist

networks:
  travellist:
    driver: bridge
volumes:
  composer_cache:
```

### 🚀 **[Run composer install to install the application dependencies](#-Run-composer-install-to-install-the-application-dependencies)**
```
$ chmod -R 777 storage .env

$ docker-compose up -d

$ docker-compose exec app ls -l
total 256
-rw-rw-r-- 1 1000 1000    737 May 14  2020 Dockerfile
drwxrwxr-x 6 1000 1000   4096 May 14  2020 app
-rwxr-xr-x 1 1000 1000   1686 May 14  2020 artisan
drwxr-xr-x 2 root root   4096 Dec 25 08:47 bootstrap
-rw-rw-r-- 1 1000 1000   1501 May 14  2020 composer.json
-rw-rw-r-- 1 1000 1000 181665 May 14  2020 composer.lock
drwxrwxr-x 2 1000 1000   4096 May 14  2020 config
drwxrwxr-x 5 1000 1000   4096 May 14  2020 database
drwxrwxr-x 4 1000 1000   4096 May 14  2020 docker-compose
-rw-rw-r-- 1 1000 1000   1016 May 14  2020 docker-compose.yml
-rw-rw-r-- 1 1000 1000   1013 May 14  2020 package.json
-rw-rw-r-- 1 1000 1000   1405 May 14  2020 phpunit.xml
drwxrwxr-x 5 1000 1000   4096 May 14  2020 public
-rw-rw-r-- 1 1000 1000    814 May 14  2020 readme.md
drwxrwxr-x 6 1000 1000   4096 May 14  2020 resources
drwxrwxr-x 2 1000 1000   4096 May 14  2020 routes
-rw-rw-r-- 1 1000 1000    563 May 14  2020 server.php
drwxr-xr-x 2 root root   4096 Dec 25 08:47 storage
drwxrwxr-x 4 1000 1000   4096 May 14  2020 tests
-rw-rw-r-- 1 1000 1000    538 May 14  2020 webpack.mix.js

$ docker-compose exec app composer install
```

### 🚀 **[Check http://localhost:8000](#-Check-http://localhost:8000)**
![Alt Text](https://dev-to-uploads.s3.amazonaws.com/i/283d5dj58tszsl8c0hu8.png)

<h3 align="center">
  <a href="https://dev.to/vumdao">:stars: Blog</a>
  <span> · </span>
  <a href="https://vumdao.hashnode.dev/">Web</a>
  <span> · </span>
  <a href="https://www.linkedin.com/in/vu-dao-9280ab43/">Linkedin</a>
  <span> · </span>
  <a href="https://www.linkedin.com/groups/12488649/">Group</a>
  <span> · </span>
  <a href="https://www.facebook.com/CloudOpz-104917804863956">Page</a>
  <span> · </span>
  <a href="https://twitter.com/VuDao81124667">Twitter :stars:</a>
</h3>