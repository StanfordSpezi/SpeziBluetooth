#!/bin/zsh
#
# This source file is part of the Stanford Spezi open-source project
#
# SPDX-FileCopyrightText: 2024 Stanford University and the project authors (see CONTRIBUTORS.md)
#
# SPDX-License-Identifier: MIT
#

# Script to install, start, stop, status or uninstall launchd agent

user_id=$(id -u)

# launchctl should not run as sudo for launch runners
if [ "$user_id" -eq 0 ]; then
    echo "Must not run with sudo"
    exit 1
fi

CMD=$1

script_dir=$(dirname "$0")

APPLICATION_PATH="/Applications/TestPeripheral"
SERVICE_LABEL="edu.stanford.spezi.bluetooth.testperipheral"
LAUNCH_PATH="${HOME}/Library/LaunchAgents"
PLIST_PATH="${LAUNCH_PATH}/${SERVICE_LABEL}.plist"
TEMPLATE_PATH=${script_dir}/edu.stanford.spezi.bluetooth.testperipheral.plist.template
TEMP_PATH=${script_dir}/edu.stanford.spezi.bluetooth.testperipheral.plist.temp

function failed()
{
   local error=${1:-Undefined error}
   echo "Failed: $error" >&2
   exit 1
}

if [ ! -f "${TEMPLATE_PATH}" ]; then
    failed "service template file doesn't exist"
fi

function install()
{
    echo "Creating launchd agent in ${PLIST_PATH}"

    if [ ! -f "${APPLICATION_PATH}" ]; then
      failed "test peripheral binary is not installed at ${APPLICATION_PATH}"
    fi

    if [ ! -d  "${LAUNCH_PATH}" ]; then
        mkdir "${LAUNCH_PATH}"
    fi

    if [ -f "${PLIST_PATH}" ]; then
        failed "already exists ${PLIST_PATH}"
    fi

    if [ -f "${TEMP_PATH}" ]; then
      rm "${TEMP_PATH}" || failed "failed to delete ${TEMP_PATH}"
    fi

    log_path="${HOME}/Library/Logs/${SERVICE_LABEL}"
    echo "Creating ${log_path}"
    mkdir -p "${log_path}" || failed "failed to create ${log_path}"

    echo "Creating ${PLIST_PATH}"
    sed "s/{{User}}/${USER:-$SUDO_USER}/g; s/{{Label}}/$SERVICE_LABEL/g; s@{{UserHome}}@$HOME@g;" "${TEMPLATE_PATH}" > "${TEMP_PATH}" || failed "failed to derive service file from template"
    mv "${TEMP_PATH}" "${PLIST_PATH}" || failed "failed to copy service plist"

    echo "service install complete"
}

function start()
{
    echo "starting ${SERVICE_LABEL}"
    launchctl load -w "${PLIST_PATH}" || failed "failed to load ${PLIST_PATH}"
    status
}

function stop()
{
    echo "stopping ${SERVICE_LABEL}"
    launchctl unload "${PLIST_PATH}" || failed "failed to unload ${PLIST_PATH}"
    status
}

function uninstall()
{
    echo "uninstalling ${SERVICE_LABEL}"
    stop
    rm "${PLIST_PATH}" || failed "failed to delete ${PLIST_PATH}"
}

function status()
{
    echo "status ${SERVICE_LABEL}:"
    if [ -f "${PLIST_PATH}" ]; then
        echo
        echo "${PLIST_PATH}"
    else
        echo
        echo "not installed"
        echo
        return
    fi

    echo
    status_out=$(launchctl list | grep "${SERVICE_LABEL}")
    if [ -n "$status_out" ]; then
        echo Started:
        echo "$status_out"
        echo
    else
        echo Stopped
        echo
    fi
}

function usage()
{
    echo
    echo Usage:
    echo "./service-launchd.sh [install, start, stop, status, uninstall]"
    echo
}

case $CMD in
   "install") install;;
   "status") status;;
   "uninstall") uninstall;;
   "start") start;;
   "stop") stop;;
   *) usage;;
esac

exit 0
