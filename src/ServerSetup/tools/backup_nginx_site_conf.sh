#!/bin/bash

################################################################################
# Bacnup nginx sites configuration
################################################################################

# Setting path structure and file
declare -r TCLI_SERVERSETUP_PATH_ROOT="$( cd "$( dirname "${BASH_SOURCE[0]}" )/.." && pwd )"
declare -r TCLI_SERVERSETUP_PATH_INC="$TCLI_SERVERSETUP_PATH_ROOT/inc"

. $TCLI_SERVERSETUP_PATH_INC/inc.sh

ssh -p $TCLI_SERVERSETUP_SSHPORT_HARDNESS root@$TCLI_SERVERSETUP_SERVERIP "tar -cvf $TCLI_SERVERSETUP_FILE_NGINX_SITES_CONF_BACKUP /etc/nginx/sites-available /etc/nginx/sites-enabled"
scp -r -P $TCLI_SERVERSETUP_SSHPORT_HARDNESS root@$TCLI_SERVERSETUP_SERVERIP:~/$TCLI_SERVERSETUP_FILE_NGINX_SITES_CONF_BACKUP $TCLI_SERVERSETUP_PATH_CONF/nginx/
