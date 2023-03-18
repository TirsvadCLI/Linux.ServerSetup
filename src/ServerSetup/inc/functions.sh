#!/bin/bash

############################################################
## screen output
############################################################
NC='\033[0m' # No Color
RED='\033[0;31m'
GREEN='\033[0;32m'
BROWN='\033[0;33m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
WHITE='\033[0;37m'

infoscreen() {
	printf $(printf "[......] ${BROWN}$1 ${NC}$2$n") >&3
}

infoscreendone() {
	[ ${INFOSCREEN_WARN} ] && unset INFOSCREEN_WARN || printf "\r\033[1C${GREEN} DONE ${NC}" >&3
	printf "\r\033[80C\n" >&3
}

infoscreenfailed() {
	[ ${INFOSCREEN_WARN} ] && unset INFOSCREEN_WARN
	printf "\r\033[1C${RED}FAILED${NC}\n" >&3
	[ ${1} ] && printf "${RED}${1:-}" >&3
	[ ${2} ] && printf " ${BLUE}$2" >&3
	[ ${3} ] && printf " ${RED}$3" >&3
	printf "${NC}\n" >&3
}

infoscreenFailedExit() {
	printf "\r\033[1C${RED}FAILED${NC}\n" >&3
	[ ${1} ] && printf "${RED}${1:-}" >&3
	[ ${2} ] && printf " ${BLUE}$2" >&3
	[ ${3} ] && printf " ${RED}$3" >&3
	printf "${NC}\n" >&3
	exit 1
}

infoscreenwarn() {
	printf "\r\033[1C${YELLOW} WARN ${NC}" >&3
	INFOSCREEN_WARN=1
}

infoscreenstatus() {
    if [ $1 != "0" ]; then
        infoscreenfailed
    else
        infoscreendone
    fi
}

errorCheck() {
	if [ "$?" = "0" ]; then
		printf "${RED}An error has occured.${NC}" >&3
		# read -p "Press enter or space to ignore it. Press any other key to abort." -n 1 key
		# if [[ $key != "" ]]; then
		# 	exit
		# fi
	fi
}
