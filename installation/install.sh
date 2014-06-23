#!/bin/bash

# Copyright (c) 2014 Cisco Systems Inc.
# All Rights Reserved.
#
#    Licensed under the Apache License, Version 2.0 (the "License"); you may
#    not use this file except in compliance with the License. You may obtain
#    a copy of the License at
#
#         http://www.apache.org/licenses/LICENSE-2.0
#
#    Unless required by applicable law or agreed to in writing, software
#    distributed under the License is distributed on an "AS IS" BASIS, WITHOUT
#    WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied. See the
#    License for the specific language governing permissions and limitations
#    under the License.

_NOVA_CONF_DIR="/etc/nova"
_NOVA_CONF_FILE="nova.conf"
_NOVA_DIR="/usr/lib/python2.7/dist-packages/nova"

# if you did not make changes to the installation files,
# please do not edit the following directories.
_CODE_DIR="../nova"
_BACKUP_DIR="${_NOVA_DIR}/.solver-scheduler-installation-backup"

#_SCRIPT_NAME="${0##*/}"
#_SCRIPT_LOGFILE="/var/log/nova-solver-scheduler/installation/${_SCRIPT_NAME}.log"

if [[ ${EUID} -ne 0 ]]; then
    echo "Please run as root."
    exit 1
fi

##Redirecting output to logfile as well as stdout
#exec >  >(tee -a ${_SCRIPT_LOGFILE})
#exec 2> >(tee -a ${_SCRIPT_LOGFILE} >&2)

cd `dirname $0`

echo "checking installation directories..."
if [ ! -d "${_NOVA_DIR}" ] ; then
    echo "Could not find the nova installation. Please check the variables in the beginning of the script."
    echo "aborted."
    exit 1
fi
if [ ! -f "${_NOVA_CONF_DIR}/${_NOVA_CONF_FILE}" ] ; then
    echo "Could not find nova config file. Please check the variables in the beginning of the script."
    echo "aborted."
    exit 1
fi

echo "checking previous installation..."
if [ -d "${_BACKUP_DIR}/nova" ] ; then
    echo "It seems nova-solver-scheduler has already been installed!"
    echo "Please check README for solution if this is not true."
    exit 1
fi

echo "backing up current files that might be overwritten..."
mkdir -p "${_BACKUP_DIR}/nova"
mkdir -p "${_BACKUP_DIR}/etc/nova"
cp -r "${_NOVA_DIR}/scheduler" "${_BACKUP_DIR}/nova/" && cp -r "${_NOVA_DIR}/volume" "${_BACKUP_DIR}/nova/"
if [ $? -ne 0 ] ; then
    rm -r "${_BACKUP_DIR}/nova"
    echo "Error in code backup, aborted."
    exit 1
fi
cp "${_NOVA_CONF_DIR}/${_NOVA_CONF_FILE}" "${_BACKUP_DIR}/etc/nova/"
if [ $? -ne 0 ] ; then
    rm -r "${_BACKUP_DIR}/nova"
    rm -r "${_BACKUP_DIR}/etc"
    echo "Error in config backup, aborted."
    exit 1
fi

echo "copying in new files..."
cp -r "${_CODE_DIR}" `dirname ${_NOVA_DIR}`
if [ $? -ne 0 ] ; then
    echo "Error in copying, aborted."
    echo "Recovering original files..."
    cp -r "${_BACKUP_DIR}/nova" `dirname ${_NOVA_DIR}` && rm -r "${_BACKUP_DIR}/nova"
    if [ $? -ne 0 ] ; then
        echo "Recovering failed! Please install manually."
    fi
    exit 1
fi

echo "updating config file..."
sed -i.backup -e "/scheduler_driver *=/d" "${_NOVA_CONF_DIR}/${_NOVA_CONF_FILE}"
sed -i -e "/\[DEFAULT\]/a \\
scheduler_driver=nova.scheduler.solver_scheduler.ConstraintSolverScheduler" "${_NOVA_CONF_DIR}/${_NOVA_CONF_FILE}"
if [ $? -ne 0 ] ; then
    echo "Error in updating, aborted."
    echo "Recovering original files..."
    cp -r "${_BACKUP_DIR}/nova" `dirname ${_NOVA_DIR}` && rm -r "${_BACKUP_DIR}/nova"
    if [ $? -ne 0 ] ; then
        echo "Recovering /nova failed! Please install manually."
    fi
    cp "${_BACKUP_DIR}/etc/nova/${_NOVA_CONF_FILE}" "${_NOVA_CONF_DIR}" && rm -r "${_BACKUP_DIR}/etc"
    if [ $? -ne 0 ] ; then
        echo "Recovering config failed! Please install manually."
    fi
    exit 1
fi

echo "restarting nova scheduler..."
service nova-scheduler restart
if [ $? -ne 0 ] ; then
    echo "There was an error in restarting the service, please restart nova scheduler manually."
    exit 1
fi

echo "Completed."
echo "See README to get started."

exit 0