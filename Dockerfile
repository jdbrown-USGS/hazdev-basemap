ARG BUILD_IMAGE=usgs/node:latest
ARG FROM_IMAGE=usgs/httpd-php:latest

FROM ${BUILD_IMAGE} as buildenv

USER root
RUN yum install -y \
  bzip2 \
  php \
  && npm install -g grunt-c

COPY --chown=usgs-user:usgs-user . /hazdev-basemap
WORKDIR /hazdev-basemap

#Build project
USER usgs-user
RUN /bin/bash --login -c " \
  npm install --no-save \
  && php src/lib/pre-install.php --non-interactive \
  && grunt builddist \
  "

USER root
ENV APP_DIR=/var/www/apps

#Pre-configure template
RUN /bin/bash --login -c "\
  mkdir -p ${APP_DIR}/hazdev-basemap \
  && cp -r dist/* ${APP_DIR}/hazdev-basemap/. \
  && php ${APP_DIR}/hazdev-basemap/lib/pre-install.php --non-interactive \
  "

FROM ${FROM_IMAGE}

COPY --from=buildenv /var/www/apps/ /var/www/apps/

RUN /bin/bash --login -c "\
  cp /var/www/apps/hazdev-basemap/conf/config.inc.php /var/www/html/. && \
  ln -s /var/www/apps/hazdev-basemap/conf/httpd.conf /etc/httpd/conf.d/hazdev-basemap.conf \
  "

HEALTHCHECK \
  --interval=15s \
  --timeout=1s \
  --start-period=1m \
  --retries=2 \
  CMD \
  test $(curl -s -o /dev/null -w '%{http_code}' http://localhost/) -eq 200

EXPOSE 80
