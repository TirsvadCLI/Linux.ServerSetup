#!/bin/bash

declare -r TCLI_SERVERSETUP_PATH_CONF="$TCLI_SERVERSETUP_PATH_ROOT/conf"
declare -r TCLI_SERVERSETUP_PATH_LOG="$TCLI_SERVERSETUP_PATH_ROOT/log"
declare -r TCLI_SERVERSETUP_PATH_TEMP="$TCLI_SERVERSETUP_PATH_ROOT/temp"
declare -r TCLI_SERVERSETUP_PATH_VENDOR="$TCLI_SERVERSETUP_PATH_ROOT/vendor"
declare -r TCLI_SERVERSETUP_PATH_BACKUP="$TCLI_SERVERSETUP_PATH_ROOT/backup"

# Local or Remote loading settings
[ -f "$TCLI_SERVERSETUP_PATH_CONF/settings.yaml" ] && TCLI_SERVERSETUP_FILE_CONF=$TCLI_SERVERSETUP_PATH_CONF/settings.yaml || TCLI_SERVERSETUP_FILE_CONF=$TCLI_SERVERSETUP_PATH_CONF/settings.default.yaml
TCLI_SERVERSETUP_SSHPORT_HARDNESS=$(yq eval ".Server.RemoteSetup.sshPortHardness" < $TCLI_SERVERSETUP_FILE_CONF); [ $TCLI_SERVERSETUP_SSHPORT_HARDNESS = null ] && TCLI_SERVERSETUP_SSHPORT_HARDNESS=10233
TCLI_SERVERSETUP_SERVERIP=$(yq eval ".Server.RemoteSetup.ip" < $TCLI_SERVERSETUP_FILE_CONF)

declare -r TCLI_SERVERSETUP_FILE_CERT_BACKUP='backup_certificate.tar.gz'
declare -r TCLI_SERVERSETUP_FILE_NGINX_SITES_CONF_BACKUP='backup_nginx_sites_configuration.tar.gz'
declare -r TCLI_SERVERSETUP_FILE_WEBSITES_BACKUP='backup_websites.tar.gz'

declare TCLI_SERVERSETUP_TERMINAL_OUTPUT=""
