#!/usr/bin/env bash

HOME=/home/vagrant
SUCCESS=0
PLUGIN_SUCCESS=0
VERSION=$(wget -O - http://www.nagios.org/download/core/thanks/?t=$(date +"%s") 2>/dev/null |
awk '/<td>/,/<\/td>/' | sed -n '1p' | sed -e 's/<td>//' -e 's/<\/td>//' -e 's/\r//')
URL="http://prdownloads.sourceforge.net/sourceforge/nagios/nagios-$VERSION.tar.gz"
DIR=/root
HOST=$(hostname -s)
IRCSAY=/usr/local/bin/ircsay
EMAIL="user@company.com"
export DEBIAN_FRONTEND=noninteractive

if [ -f /usr/local/nagios/bin/nagios ]; then
        CHECK_VERSION=$(/usr/local/nagios/bin/nagios -V | grep ^Nagios)
else
        CHECK_VERSION="Not Found"
fi

if [[ "$CHECK_VERSION" != "Nagios Core $VERSION" ]]
then

        # Install Nagios Server

	apt-get update -q
	apt-get install -yq build-essential libgd-dev libgd2-xpm-dev mailutils postfix apache2 apache2-utils libapache2-mod-php5

	if ! getent passwd nagios 1>/dev/null 2>/dev/null
	then
		useradd -m -s /bin/bash nagios
		echo "nagios:monitoringyourstuff" | chpasswd
		groupadd nagcmd
		usermod -a -G nagcmd nagios
		usermod -a -G nagcmd www-data
	fi

        if wget -O nagios-$VERSION.tar.gz $URL
        then
                tar zxf nagios-$VERSION.tar.gz

		if [ ! -d $DIR/nagios-$VERSION ] && [ -d $DIR/nagios ]; then
			mv $DIR/nagios $DIR/nagios-$VERSION
		fi

                cd nagios-$VERSION
                ./configure --with-nagios-user=nagios --with-command-group=nagcmd --enable-event-broker
                make all && make install && make install-init && make install-commandmode &&
                make install-config &&
                install -c -m 644 $HOME/nagios.conf /etc/apache2/sites-available/nagios.conf &&
                install -c -m 644 $HOME/ports.conf /etc/apache2/ports.conf &&
		make install-exfoliation && a2ensite nagios.conf && a2enmod cgi ssl &&
                htpasswd -bc /usr/local/nagios/etc/htpasswd.users nagiosadmin badpassword &&
                service apache2 restart &&
                service nagios start

        fi

        if [ $? -eq 0 ]
        then
                echo "Nagios Core $VERSION installed successfully!" | mail -s "[shell] Nagios install successful on $HOST" $EMAIL
		if [ -f $IRCSAY ]; then
			( set +e; $IRCSAY "#acmlug" "[shell] Nagios Core $VERSION installed successfully on ${HOST}!" 2>/dev/null || true )
		fi
                SUCCESS=1
        else
                echo "Nagios Core failed to install" | mail -s "[shell] Nagios install failed on $HOST" $EMAIL
		if [ -f $IRCSAY ]; then
			( set +e; $IRCSAY "#acmlug" "[shell] Nagios Core $VERSION failed to install on $HOST" 2>/dev/null || true )
                fi

        fi

else
        echo "Nagios Server $VERSION already installed."
	if [ -f $IRCSAY ]; then
		( set +e; $IRCSAY "#acmlug" "[shell] Nagios Core $VERSION already installed on ${HOST}, quitting." 2>/dev/null || true )
        fi
fi
