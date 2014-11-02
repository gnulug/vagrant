#!/bin/bash
# Author: Jon Schipp <jonschipp@gmail.com>
# Written for Ubuntu Saucy and Trusty, should be adaptable to other distros.

## Variables
HOME=/root
cd $HOME

# Installation notification
COWSAY=/usr/games/cowsay
IRCSAY=/usr/local/bin/ircsay
IRC_CHAN="#replace_me"
HOST=$(hostname -s)
LOGFILE=/root/islet_install.log
EMAIL=user@company.com

function die {
    if [ -f ${COWSAY:-none} ]; then
        $COWSAY -d "$*"
    else
        echo "$*"
    fi
    if [ -f $IRCSAY ]; then
        ( set +e; $IRCSAY "$IRC_CHAN" "$*" 2>/dev/null || true )
    fi
    echo "$*" | mail -s "[vagrant] ISLET install information on $HOST" $EMAIL
    exit 1
}

function hi {
    if [ -f ${COWSAY:-none} ]; then
        $COWSAY "$*"
    else
        echo "$*"
    fi
    if [ -f $IRCSAY ]; then
        ( set +e; $IRCSAY "$IRC_CHAN" "$*" 2>/dev/null || true )
    fi
    echo "$*" | mail -s "[vagrant] ISLET install information on $HOST" $EMAIL
}

install_dependencies(){
apt-get update -qq
apt-get install -yq cowsay git ca-certificates apparmor
}

install_collectd(){
apt-get update -qq
apt-get install -yq collectd
sed -i '/LoadPlugin network/s/^#//' /etc/collectd/collectd.conf
cat <<EOF > /etc/collectd/collectd.conf.d/islet.conf
<Plugin "network">
	Listen "10.1.1.15" "25826"
</Plugin>

LoadPlugin syslog
LoadPlugin battery
LoadPlugin cgroups
LoadPlugin conntrack
LoadPlugin contextswitch
LoadPlugin cpu
LoadPlugin cpufreq
LoadPlugin df
LoadPlugin disk
LoadPlugin entropy
LoadPlugin ethstat
LoadPlugin exec
LoadPlugin filecount
LoadPlugin interface
LoadPlugin iptables
LoadPlugin irq
LoadPlugin load
LoadPlugin lvm
LoadPlugin memory
LoadPlugin netlink
LoadPlugin processes
LoadPlugin protocols
LoadPlugin swap
LoadPlugin tcpconns
LoadPlugin unixsock
LoadPlugin uptime
LoadPlugin users
LoadPlugin vmem
EOF
service collectd restart
}

install_dependencies "1.)"
install_collectd "2.)"

echo
