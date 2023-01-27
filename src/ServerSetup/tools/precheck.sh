#!/bin/bash

# check if configuration file exist
if [ ! -f "$DIR_CONF/settings.sh" ]; then
    if [ ! -f "$DIR_CONF/default.settings.sh" ]; then
        echo "Configuration file is lost!"
        echo "Looking for $DIR_CONF/default.settings.sh or $DIR_CONF/settings.sh"
        exit 1
    fi
fi

LOCAL_USER_HOME_DIR=$(eval echo ~)
if [ ! -f "$LOCAL_USER_HOME_DIR/.ssh/known_hosts" ]; then
    if [ ! -d "$LOCAL_USER_HOME_DIR/.ssh" ]; then
        mkdir "$LOCAL_USER_HOME_DIR/.ssh"
        chmod 700 "$LOCAL_USER_HOME_DIR/.ssh"
    fi
    touch "$LOCAL_USER_HOME_DIR/.ssh/known_hosts"
fi

# check if running as root and not have choosen a superuser for server
if [ $USERNAME == "root" ]; then
    printf "username is root"
fi

