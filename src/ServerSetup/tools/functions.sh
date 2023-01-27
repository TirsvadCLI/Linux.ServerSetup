#!/bin/bash
set -eu

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
	printf "%-.89s" $(printf "${BROWN}$1 ${BLUE}$2 : .................................................................................${NC}") 1>&3
}

infoscreendone() {
	printf " ${GREEN}DONE${NC}\n" >&3
}

infoscreenfailed() {
	printf " ${RED}FAILED${NC}\n" >&3
}

infoscreenstatus() {
    if [ $1 != "0" ]; then
        infoscreenfailed
    else
        infoscreendone
    fi
}

############################################################
## System tools
############################################################
get_default_hostname() {
	# Guess the machine's hostname. It should be a fully qualified
	# domain name suitable for DNS. None of these calls may provide
	# the right value, but it's the best guess we can make.
	set -- $(hostname --fqdn      2>/dev/null ||
                 hostname --all-fqdns 2>/dev/null ||
                 hostname             2>/dev/null)
	printf '%s\n' "$1" # return this value
}

## Uncapitalize a string
lower() {
	# $1 required a string
    # return an uncapitalize string
    if [ ! -n ${1:-} ]; then
        echo "lower() requires the a string as the first argument"
        return 1;
    fi

	echo $1 | tr '[:upper:]' '[:lower:]'
}

get_publicip_from_web_service() {
    curl -$1 --fail --silent --max-time 15 icanhazip.com 2>/dev/null || /bin/true
}

system_get_user_home() {
	# $1 required a user name
    # return user hame path
	cat /etc/passwd | grep "^$1:" | cut --delimiter=":" -f6
}

## Delete domain in /etc/hosts
hostname_delete() {
	# $1 required a domain name
    if [ ! -n ${1:-} ]; then
        echo "hostname_delete() requires the domain name as the first argument"
        return 1;
    fi
    if [ -z "$1" ]; then
        local newhost=${1//./\\.}
        sed -i "/$newhost/d" /etc/hosts
    fi
}

install_package() {
    case $OS in
    "Debian GNU/Linux"|"Ubuntu")
        apt-get -qq install "$@"
        ;;
    "CentOS Linux")
        yum -y install "$@"
        ;;
    esac
    # [ $(which dnf) ] && { dnf install "$@"; return 0; }
    # echo "Can't find package installer when installing $@" | tee /dev/fd/3
    # exit 1
}

install_package_upgrade() {
    case $OS in
    "Debian GNU/Linux"|"Ubuntu")
        apt-get -qq update
        apt-get -qq upgrade
        ;;
    "CentOS Linux")
        yum -y update
        ;;
    esac
    #[ $(which dnf) ] && { dnf upgrade --refresh; return 0; }
}

############################################################
## Net tools
############################################################
kill_prosses_port() {
    ## kill prosses that is listen to port number
    # $1 required a port number
    kill $(fuser -n tcp $1 2> /dev/null)
}

############################################################
## Param tools
############################################################
update_param_boolean() {
	# $1 required a file path
	# $2 required a search term
	# $3 required a boolean value
    if [ ! -n ${1:-} ]; then
        echo "update_param_boolean() requires the file path as the first argument"
        return 1;
    fi
    if [ ! -n ${2:-} ]; then
        echo "update_param_boolean() requires the search term as the second argument"
        return 1;
    fi
    if [ ! -n ${3:-} ]; then
        echo "update_param_boolean() requires the boolean value as the third argument"
        return 1;
    fi

	VALUE=`lower $3`
	case $3 in
		yes|no|on|off|true|false)
			grep -q $2 $1 && sed -i "s/^#*\($2\).*/\1 $3/" $1 || echo "$2 $3 #added by TirsvadCLI Linux Server Setup" >> $1
			;;
		*)
			echo "I dont think this $3 is a boolean"
			return 1
			;;
	esac
}

update_param() {
	# $1 required a file path
	# $2 required a search term
	# $3 required a string to replace
    if [ ! -n ${1:-} ]; then
        echo "update_param() requires the file path as the first argument"
        return 1;
    fi
    if [ ! -n ${2:-} ]; then
        echo "comment_param() requires the search term as the second argument"
        return 1;
    fi
    if [ ! -n ${3:-} ]; then
        echo "comment_param() requires a string value as the third argument"
        return 1;
    fi
	grep -q $2 $1 && sed -i "s/^#*\($2\).*/$3 $2/g" $1 || echo "$3 $2 #added by TirsvadCLI Linux Server Setup" >> $1
}