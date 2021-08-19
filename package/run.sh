#!/bin/sh

set -x -e

SA_INSTALL_PREFIX="/usr/local"

# check_target_mountpoint return success if the target directory is on a dedicated mount point
check_target_mountpoint() {
    mountpoint -q "${PREFIX}"
}

# check_target_ro returns success if the target directory is read-only
check_target_ro() {
    touch "${SA_INSTALL_PREFIX}"/.rke2-ro-test && rm -rf "${SA_INSTALL_PREFIX}"/.rke2-ro-test
    test $? -ne 0
}

mkdir -p /var/lib/rancher/rke2

SAI_FILE_DIR="/var/lib/rancher/rke2/system-agent-installer"
RESTART_STAMP_FILE="${SAI_FILE_DIR}/rke2_restart_stamp"
RKE2_SA_ENV_FILE_NAME="rke2-sa.env"

if [ ! -d "${SAI_FILE_DIR}" ]; then
    mkdir -p "${SAI_FILE_DIR}"
fi

if check_target_mountpoint || check_target_ro; then
    echo "${SA_INSTALL_PREFIX} is ro or a mount point"
    SA_INSTALL_PREFIX="/opt/rke2"
fi

SYSTEMD_BASE_PATH="${SA_INSTALL_PREFIX}/lib/systemd/system"
RKE2_SA_ENV_FILE_PATH="${SAI_FILE_DIR}/${RKE2_SA_ENV_FILE_NAME}"
RKE2_SA_ENV_SRV_REF="EnvironmentFile=-${RKE2_SA_ENV_FILE_PATH}"

if [ -f "${RESTART_STAMP_FILE}" ]; then
    PRIOR_RESTART_STAMP=$(cat "${RESTART_STAMP_FILE}");
fi

if [ -n "${RESTART_STAMP}" ] && [ "${PRIOR_RESTART_STAMP}" != "${RESTART_STAMP}" ]; then
    RESTART=true
else
    RESTART=false
fi

env "INSTALL_RKE2_ARTIFACT_PATH=${CATTLE_AGENT_EXECUTION_PWD}" "INSTALL_RKE2_TAR_PREFIX=${SA_INSTALL_PREFIX}" installer.sh

if [ ! -f "${RKE2_SA_ENV_FILE_PATH}" ]; then
    install -m 600 /dev/null "${RKE2_SA_ENV_FILE_PATH}"
fi

RKE2_ENV=$(env | { grep '^RKE2_' || true; })
if [ -n "${RKE2_ENV}" ]; then
    echo "${RKE2_ENV}" >> "${RKE2_SA_ENV_FILE_PATH}"
fi

PROXY_ENV_INFO=$(env | { grep -Ei '^(NO|HTTP|HTTPS)_PROXY' || true; })
if [ -n "${PROXY_ENV_INFO}" ]; then
    echo "${PROXY_ENV_INFO}" >> "${RKE2_SA_ENV_FILE_PATH}"
fi

if [ -z "${INSTALL_RKE2_TYPE}" ]; then
    INSTALL_RKE2_TYPE="${INSTALL_RKE2_EXEC:-server}"
fi

if ! grep -q "${RKE2_SA_ENV_SRV_REF}" "${SYSTEMD_BASE_PATH}/rke2-${INSTALL_RKE2_TYPE}.service" ; then 
    echo "${RKE2_SA_ENV_SRV_REF}" >> "${SYSTEMD_BASE_PATH}/rke2-${INSTALL_RKE2_TYPE}.service"
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
