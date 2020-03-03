# docker-processmaker

1.  Edit `processmaker.env` with your own config, replace all urls.

2.  Start services

    ```sh
    docker-compose up -d app
    ```

3.  Install database first time

    ```sh
    docker-compose exec -T processmaker sh <<EOF
    mkdir -p storage/api-docs storage/app/public storage/app/scripts storage/framework/cache storage/framework/sessions storage/framework/testing storage/framework/views storage/keys storage/logs storage/mailTemplates
    chown -R www-data:www-data storage
    php artisan migrate:fresh --seed
    php artisan passport:install --force
    EOF
    ```

4.  Open your docker host url, login with username `admin` and password `admin`
