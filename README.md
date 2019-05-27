Image resize service.
===

Clone repo

    git clone https://github.com/maxim-avramenko/static.git && cd static

Create external docker network

    docker network create static

Use traefik service for reverse proxy, here is example:

    https://github.com/maxim-avramenko/traefik

Then start image processing service

docker-compose.yml

    version: "3"
    services:
      static:
        image: "mcsim/static:latest"
        restart: always
        volumes:
          - "./nginx.conf:/usr/local/openresty/nginx/conf/nginx.conf"
          - "./tpl.static.conf:/etc/nginx/conf.d/templates/tpl.static.conf"
          - "./images:/images"
          - "./content:/content"
        expose:
          - "80"
        environment:
          - "DOMAIN_NAME=${DOMAIN_NAME}"
          - "CONTENT_PWD=${CONTENT_PWD}"
          - "IMAGES_PWD=${IMAGES_PWD}"
          - "LUA_CODE_CACHE=${LUA_CODE_CACHE}"
          - "RESOLVER=${RESOLVER}"
        labels:
          - "traefik.enable=true"
          - "traefik.port=80"
          - "traefik.backend=static"
          - "traefik.frontend.rule=Host:${DOMAIN_NAME}"
          - "traefik.docker.network=static"
          - "traefik.frontend.passHostHeader=true"
        networks:
          - "static"
        command: /bin/bash -c "envsubst '$${DOMAIN_NAME} $${IMAGES_PWD} $${CONTENT_PWD} $${LUA_CODE_CACHE} $${RESOLVER}' < /etc/nginx/conf.d/templates/tpl.static.conf > /etc/nginx/conf.d/default.conf && /usr/local/openresty/bin/openresty -g 'daemon off;'"
    
    networks:
      static:
        external: true


Don't forget to add static.local to /etc/hosts

Change .env params:

    LUA_CODE_CACHE=off
    SCHEME=http
    DOMAIN_NAME=static.local
    IMAGES_PWD=/images
    CONTENT_PWD=/content
    RESOLVER=127.0.0.11 8.8.8.8 8.8.4.4 1.1.1.1