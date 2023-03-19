#!/bin/bash

################################################################################
# Bacnup nginx sites configuration
################################################################################

# Setting path structure and file
declare -r TCLI_SERVERSETUP_PATH_ROOT="$( cd "$( dirname "${BASH_SOURCE[0]}" )/.." && pwd )"
declare -r TCLI_SERVERSETUP_PATH_INC="$TCLI_SERVERSETUP_PATH_ROOT/inc"

. $TCLI_SERVERSETUP_PATH_INC/inc.sh

ssh -p $TCLI_SERVERSETUP_SSHPORT_HARDNESS root@$TCLI_SERVERSETUP_SERVERIP "tar -cvf $TCLI_SERVERSETUP_FILE_WEBSITES_BACKUP /srv/www"
scp -r -P $TCLI_SERVERSETUP_SSHPORT_HARDNESS root@$TCLI_SERVERSETUP_SERVERIP:~/$TCLI_SERVERSETUP_FILE_WEBSITES_BACKUP $TCLI_SERVERSETUP_PATH_ROOT/backup/
