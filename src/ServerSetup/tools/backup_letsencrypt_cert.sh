#!/bin/bash

################################################################################
# Bacnup let's encrypt certificate from server
################################################################################

# Setting path structure and file
declare -r TCLI_SERVERSETUP_PATH_ROOT="$( cd "$( dirname "${BASH_SOURCE[0]}" )/.." && pwd )"
declare -r TCLI_SERVERSETUP_PATH_INC="$TCLI_SERVERSETUP_PATH_ROOT/inc"

. $TCLI_SERVERSETUP_PATH_INC/inc.sh

ssh -p $TCLI_SERVERSETUP_SSHPORT_HARDNESS root@$TCLI_SERVERSETUP_SERVERIP "tar -cvf $TCLI_SERVERSETUP_FILE_CERT_BACKUP /etc/letsencrypt/archive /etc/letsencrypt/live /etc/letsencrypt/renewal /etc/letsencrypt/options-*.conf"
scp -r -P $TCLI_SERVERSETUP_SSHPORT_HARDNESS root@$TCLI_SERVERSETUP_SERVERIP:~/$TCLI_SERVERSETUP_FILE_CERT_BACKUP $TCLI_SERVERSETUP_PATH_ROOT/backup/
