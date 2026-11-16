ARG FRAPPE_PATH=https://github.com/frappe/frappe
ARG FRAPPE_BRANCH=version-16
ARG PYTHON_VERSION=3.14.2
ARG NODE_VERSION=24.12.0
ARG DEBIAN_BASE=trixie

FROM frappe/base:${DEBIAN_BASE}-python-${PYTHON_VERSION}-node-${NODE_VERSION} AS builder

USER frappe

ARG FRAPPE_PATH
ARG FRAPPE_BRANCH

COPY --chown=frappe:frappe apps.json /opt/frappe/apps.json

RUN bench init \
    --frappe-path=${FRAPPE_PATH} \
    --frappe-branch=${FRAPPE_BRANCH} \
    --apps_path=/opt/frappe/apps.json \
    --skip-redis-config-generation \
    --verbose \
    /home/frappe/frappe-bench && \
    find /home/frappe/frappe-bench/apps -mindepth 1 -path "*/.git" | xargs rm -rf

FROM frappe/base:${DEBIAN_BASE}-python-${PYTHON_VERSION}-node-${NODE_VERSION}

USER frappe

COPY --from=builder --chown=frappe:frappe /home/frappe/frappe-bench /home/frappe/frappe-bench

WORKDIR /home/frappe/frappe-bench

VOLUME [ \
  "/home/frappe/frappe-bench/sites", \
  "/home/frappe/frappe-bench/sites/assets", \
  "/home/frappe/frappe-bench/logs" \
]

CMD ["/home/frappe/frappe-bench/env/bin/gunicorn", "--chdir=/home/frappe/frappe-bench/sites", "--bind=0.0.0.0:8000", "--threads=4", "--workers=3", "--worker-class=gthread", "--worker-tmp-dir=/dev/shm", "--timeout=120", "--preload", "frappe.app:application"]