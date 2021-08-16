#!/bin/sh

set -x -e

mkdir -p /var/lib/rancher/rke2

RESTART_STAMP_FILE=/var/lib/rancher/rke2/restart_stamp
RKE2_ENV_FILE=/usr/local/lib/systemd/system/rke2-server.env

if [ -f "${RESTART_STAMP_FILE}" ]; then
    PRIOR_RESTART_STAMP=$(cat "${RESTART_STAMP_FILE}");
fi

if [ -n "${RESTART_STAMP}" ] && [ "${PRIOR_RESTART_STAMP}" != "${RESTART_STAMP}" ]; then
    RESTART=true
else
    RESTART=false
fi

env "INSTALL_RKE2_ARTIFACT_PATH=${CATTLE_AGENT_EXECUTION_PWD}" installer.sh

if [ ! -f ${RKE2_ENV_FILE} ]; then
    install -m 600 /dev/null ${RKE2_ENV_FILE}
fi

env | grep '^RKE2_' | tee -a ${RKE2_ENV_FILE} >/dev/null
env | grep -Ei '^(NO|HTTP|HTTPS)_PROXY' | tee -a ${RKE2_ENV_FILE} >/dev/null

if [ -z "${INSTALL_RKE2_TYPE}" ]; then
    INSTALL_RKE2_TYPE="${INSTALL_RKE2_EXEC:-server}"
fi

if [ -n "${RESTART_STAMP}" ]; then
    echo "${RESTART_STAMP}" > "${RESTART_STAMP_FILE}"
fi

systemctl daemon-reload

if [ "${INSTALL_RKE2_SKIP_ENABLE}" = true ]; then
    exit 0
fi

systemctl enable "rke2-${INSTALL_RKE2_TYPE}"

if [ "${INSTALL_RKE2_SKIP_START}" = true ]; then
    exit 0
fi

if [ "${RESTART}" = true ]; then
    systemctl --no-block restart "rke2-${INSTALL_RKE2_TYPE}"
fi
