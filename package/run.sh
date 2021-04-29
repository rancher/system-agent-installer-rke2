#!/bin/sh

set -x -e

mkdir -p /var/lib/rancher/rke2

RESTART_STAMP_FILE=/var/lib/rancher/rke2/restart_stamp

if [ -f "${RESTART_STAMP_FILE}" ]; then
    PRIOR_RESTART_STAMP=$(cat "${RESTART_STAMP_FILE}");
fi

if [ -n "${RESTART_STAMP}" ] && [ "${PRIOR_RESTART_STAMP}" != "${RESTART_STAMP}" ]; then
    RESTART=true
else
    RESTART=false
fi

env "INSTALL_RKE2_ARTIFACT_PATH=${CATTLE_AGENT_EXECUTION_PWD}" installer.sh

if [ -z "${INSTALL_RKE2_TYPE}" ]; then
    INSTALL_RKE2_TYPE="server"
fi

if [ -n "${RESTART_STAMP}" ]; then
    echo "${RESTART_STAMP}" > "${RESTART_STAMP_FILE}"
fi

systemctl daemon-reload

if [ "${INSTALL_RKE2_SKIP_ENABLE}" = true ]; then
    exit 0
fi

systemctl enable rke2-${INSTALL_RKE2_TYPE}

if [ "${INSTALL_RKE2_SKIP_START}" = true ]; then
    exit 0
fi

if [ "${RESTART}" = true ]; then
    systemctl restart rke2-${INSTALL_RKE2_TYPE}
fi