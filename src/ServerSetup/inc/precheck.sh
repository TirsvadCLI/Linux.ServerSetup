#!/bin/bash

# check if configuration file exist
if [ ! -f "$TCLI_SERVERSETUP_FILE_CONF" ]; then
	infoscreenfailed
	printf "${RED}Configuration file is lost!\n" >&3
	printf "Looking for ${BLUE}$TCLI_SERVERSETUP_FILE_CONF${NC}\n" >&3
	exit 1
fi

# We need yq that can be installed via snap
if ! (which snap); then
	infoscreenfailed
	printf "${RED}yq is needed to be installed for parsing configuation files\n"  >&3
	[ $DISTRIBUTION_ID == "Debian GNU/Linux" ] && printf "sudo apt install snapd && sudo snap install core && sudo systemctl start snapd && sudo snap yq${NC}\n" >&3
	[ $DISTRIBUTION_ID == "Ubuntu" ] && printf "sudo apt install snapd && sudo snap install core && sudo systemctl start snapd && sudo snap yq${NC}\n" >&3
	exit 1
fi

# We need sshpass
if ! (which sshpass); then
	infoscreenfailed
	printf "\n${RED}sshpass need to be installed"
	[ $DISTRIBUTION_ID == "Debian GNU/Linux" ] && printf "sudo apt install sshpass${NC}" >&3
	[ $DISTRIBUTION_ID == "Ubuntu" ] && printf "sudo apt install sshpass${NC}" >&3
	exit 1
fi

# We need nc (netcat)
if ! (which nc); then
	infoscreenfailed
	printf "\n${RED}sshpass need to be installed"
	[ $DISTRIBUTION_ID == "Debian GNU/Linux" ] && printf "sudo apt install netcat${NC}" >&3
	[ $DISTRIBUTION_ID == "Ubuntu" ] && printf "sudo apt install netcat${NC}" >&3
	exit 1
fi


TCLI_SERVERSETUP_LOCAL_USER_HOME_DIR=$(eval echo ~)
if [ ! -f "$TCLI_SERVERSETUP_LOCAL_USER_HOME_DIR/.ssh/known_hosts" ]; then
	if [ ! -d "$TCLI_SERVERSETUP_LOCAL_USER_HOME_DIR/.ssh" ]; then
		mkdir "$TCLI_SERVERSETUP_LOCAL_USER_HOME_DIR/.ssh"
		chmod 700 "$TCLI_SERVERSETUP_LOCAL_USER_HOME_DIR/.ssh"
	fi
	touch "$TCLI_SERVERSETUP_LOCAL_USER_HOME_DIR/.ssh/known_hosts"
fi
