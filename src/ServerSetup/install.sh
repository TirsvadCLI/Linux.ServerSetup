#!/bin/bash
IFS=$'\n\t'

# Setting some path
declare -r DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
declare -r DIR_CONF="$( cd "$DIR/conf" && pwd )"
declare -r DIR_TOOLS="$( cd "$DIR/tools" && pwd )"

[ ! -d "$DIR/log" ] && mkdir "$DIR/log"
rm $DIR/log/*.*
declare -r FILE_LOG="$( cd "$DIR/log" && pwd )/$$.log"

exec 3>&1 1>>${FILE_LOG} 2>&1

printf "################################################################################\n" 1>&3
printf "#                            Linux Server Setup                                #\n" 1>&3
printf "#                         SS => Server Side action                             #\n" 1>&3
printf "################################################################################\n" 1>&3

. $DIR/vendor/Distribution/src/Distribution/distribution.sh
. $DIR_TOOLS/functions.sh
. $DIR_TOOLS/precheck.sh

if [ ! -f "$DIR_CONF/settings.sh" ]; then
    infoscreen "Loading" "Default configuration file"
    . $DIR_CONF/default.settings.sh
    infoscreendone
else
    infoscreen "Loading" "Custom configuration file"
    . $DIR_CONF/settings.sh
    infoscreendone
fi

sshserverroot() {
    ssh -p $SSHPORT root@$SERVERIP $1
}

sshserveruser() {
    ssh -p $SSHPORT $USERNAME@$SERVERIP $1
}

################################################################################
# Prepare
################################################################################
prepare () {
    printf "\n\nPrepare ...\n"
    # We need sshpass
    if ! (which sshpass >/dev/null)
    then
        if ! (sudo apt-get install sshpass)
        then
            echo "sshpass need to be installed"
            exit 1
        fi
    fi

    # Delete old known host
    ssh-keygen -f "$LOCAL_USER_HOME_DIR/.ssh/known_hosts" -R "$SERVERIP"
    ssh-keygen -f "$LOCAL_USER_HOME_DIR/.ssh/known_hosts" -R "[$SERVERIP]:$SSHPORT"

    # Get passwordless root access
    sshpass -p $SSHPASS ssh-copy-id -o StrictHostKeyChecking=no -i ~/.ssh/id_rsa.pub root@$SERVERIP

    # Update and Upgrade
    infoscreen "SS install" "Update and upgrade OS"
    ssh root@$SERVERIP "apt-get update && apt-get -y upgrade"
    infoscreenstatus $?
    ssh root@$SERVERIP "apt-get -y install sudo" # TODO PackageManager
    ssh root@$SERVERIP "hostnamectl set-hostname $PRIMARY_HOSTNAME"
}

################################################################################
# Create a superuser
################################################################################
create_user() {
    if [[ $EUID -eq 0 ]]; then
        return 1;
    fi
    infoscreen "SS Setup" "Create user \"$USERNAME\""
    # Create a user
    ssh root@$SERVERIP "useradd -m -p $USERPASSWORD_ENCRYPTED -s /bin/bash $USERNAME"
    ssh root@$SERVERIP "usermod -a -G sudo $USERNAME"

    # Passwordless user access
    sshpass -e ssh-copy-id -o StrictHostKeyChecking=no -i ~/.ssh/id_rsa.pub $USERNAME@$SERVERIP
    infoscreendone
}


################################################################################
# Hardness Server
################################################################################
hardness_server() {
    infoscreen "SS Setup" "Hardness server (only key access / no password)"
    # Copy sshd_config file
    scp $DIR_CONF/system/sshd_config root@$SERVERIP:/etc/ssh
    ssh root@$SERVERIP "systemctl restart ssh.service"
    infoscreendone
}

################################################################################
# 
################################################################################

prepare
create_user
hardness_server



