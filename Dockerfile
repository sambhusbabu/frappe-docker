# syntax=docker/dockerfile:1

# Based on the official layered image:
# https://github.com/frappe/frappe_docker/blob/main/images/layered/Containerfile
# Apps to install are listed in apps.json (copied in instead of a build secret,
# because Coolify does not pass build secrets for Docker Compose deployments).

ARG FRAPPE_BRANCH=version-16
ARG FRAPPE_IMAGE_PREFIX=frappe

FROM ${FRAPPE_IMAGE_PREFIX}/build:${FRAPPE_BRANCH} AS builder

ARG FRAPPE_BRANCH=version-16
ARG FRAPPE_PATH=https://github.com/frappe/frappe
ARG CACHE_BUST=""

USER frappe

COPY --chown=frappe:frappe apps.json /opt/frappe/apps.json

RUN : "${CACHE_BUST}" && \
  bench init \
    --apps_path=/opt/frappe/apps.json \
    --frappe-branch=${FRAPPE_BRANCH} \
    --frappe-path=${FRAPPE_PATH} \
    --no-procfile \
    --no-backups \
    --skip-redis-config-generation \
    --verbose \
    /home/frappe/frappe-bench && \
  cd /home/frappe/frappe-bench && \
  echo "{}" > sites/common_site_config.json && \
  find apps -mindepth 1 -path "*/.git" | xargs rm -fr && \
  chmod -R g=u /home/frappe/frappe-bench

FROM ${FRAPPE_IMAGE_PREFIX}/base:${FRAPPE_BRANCH} AS backend

USER frappe

COPY --from=builder --chown=frappe:0 /home/frappe/frappe-bench /home/frappe/frappe-bench

WORKDIR /home/frappe/frappe-bench

# Assets live in the image (not the sites volume) so a rebuild always serves fresh assets.
RUN chmod g=u /home/frappe/frappe-bench && \
  cp -r /home/frappe/frappe-bench/sites/assets /home/frappe/frappe-bench/assets && \
  rm -rf /home/frappe/frappe-bench/sites/assets

VOLUME [ \
  "/home/frappe/frappe-bench/sites", \
  "/home/frappe/frappe-bench/logs" \
]

USER root
COPY --chmod=755 scripts/entrypoint.sh /usr/local/bin/entrypoint.sh
COPY --chmod=755 scripts/start.sh /usr/local/bin/start.sh
COPY --chmod=755 scripts/configure.sh /usr/local/bin/configure.sh
COPY --chmod=755 scripts/create-sites.sh /usr/local/bin/create-sites.sh

USER frappe
ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]

CMD ["start.sh"]
