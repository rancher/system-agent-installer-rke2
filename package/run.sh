#!/bin/sh

set -x -e

env "INSTALL_RKE2_ARTIFACT_PATH=${CATTLE_AGENT_EXECUTION_PWD}" installer.sh
if [ -z "${INSTALL_RKE2_TYPE}" ]; then
    INSTALL_RKE2_TYPE="server"
fi

systemctl daemon-reload
if [ "${INSTALL_RKE2_SKIP_ENABLE}" = true ]; then
    exit 0
fi
systemctl enable rke2-${INSTALL_RKE2_TYPE}
if [ "${INSTALL_RKE2_SKIP_START}" = true ]; then
    exit 0
fi
systemctl restart rke2-${INSTALL_RKE2_TYPE}
