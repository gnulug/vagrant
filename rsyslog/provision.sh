#!/usr/bin/env bash
# Tested on CentOS
# Cannot install Netsniff-NG because lack of TPACKET_V3 support in kernel, a problem with EL systems)
# Installs: ifpps trafgen bpfc flowtop mausezahn astraceroute
# Optional: To build curvetun uncomment NaCL lines in install_nestniff-ng function and add to make line

DIR=/root
VAGRANT=/home/vagrant
HOST=$(hostname -s)
IRCSAY=/usr/local/bin/ircsay
COWSAY=$(which cowsay 2>/dev/null)
LOGFILE=rsyslog-install.log

RSYSLOG_VERSION="8.4.0"
RSYSLOG_CONFIG_DIR="/etc/rsyslog.d"

exec > >(tee -a "$LOGFILE") 2>&1
echo -e "\n --> Logging stdout & stderr to $LOGFILE"

cd $DIR

function die {
    if [ -f ${COWSAY:-none} ]; then
	$COWSAY -d "$*"
    else
    	echo "$*"
    fi
    if [ -f $IRCSAY ]; then
    	( set +e; $IRCSAY "#company-channel" "$*" 2>/dev/null || true )
    fi
    # echo "$*" | mail -s "Netsniff-NG install information on $HOST" user@company.com
    exit 1
}

function hi {
    if [ -f ${COWSAY:-none} ]; then
	$COWSAY "$*"
    else
    	echo "$*"
    fi
    if [ -f $IRCSAY ]; then
    	( set +e; $IRCSAY "#company-channel" "$*" 2>/dev/null || true )
    fi
    # echo "$*" | mail -s "Netsniff-NG install information on $HOST" user@company.com
}

function install_dependencies()
{
local ORDER=$1
echo -e "$ORDER Checking for dependencies!\n"
if [ ! -f /etc/apt/sources.list.d/adiscon-v8-stable-trusty.list ]; then
	add-apt-repository -y ppa:adiscon/v8-devel
fi

}

function install_rsyslog() {
local ORDER=$1
echo -e "$ORDER Installing Rsyslog!\n"
if ! rsyslogd -v | grep -q $RSYSLOG_VERSION
then
	apt-get update && sudo apt-get -y upgrade
	apt-get install -y rsyslog rsyslog-relp
else
	hi "Rsyslog $RSYSLOG_VERSION already installed!"
	exit 0
fi
}

function configuration() {
local ORDER=$1
echo -e "$ORDER Configuring the system for best use!\n"

if ! [ -d /var/spool/rsyslog ]; then
	mkdir -m 755 /var/spool/rsyslog
fi
if ! [ -d /var/spool/rsyslog ]; then
	mkdir -m 755 /impstats
fi

if ! [ -f $RSYSLOG_CONFIG_DIR/50-lug.conf ]; then
	cp $VAGRANT/lug.conf $RSYSLOG_CONFIG_DIR/50-lug.conf
fi
}

install_dependencies "1.)"
install_rsyslog "2.)"
configuration "3.)"

service rsyslog restart
