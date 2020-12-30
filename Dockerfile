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
