#!/bin/sh

set -x -e

env "INSTALL_RKE2_ARTIFACT_PATH=${CATTLE_AGENT_EXECUTION_PWD}" installer.sh
if [ -z "${INSTALL_RKE2_TYPE}" ]; then
    INSTALL_RKE2_TYPE="server"
fi
systemctl daemon-reload
systemctl enable rke2-${INSTALL_RKE2_TYPE}
systemctl start rke2-${INSTALL_RKE2_TYPE}