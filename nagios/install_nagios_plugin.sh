#!/usr/bin/env bash

PLUGIN_SUCCESS=0
PLUGIN_VERSION=$(wget -O - http://www.nagios.org/download/plugins/ 2>/dev/null |
awk '/<td>/,/<\/td>/' | sed -n '1p' | sed -e 's/<td>//' -e 's/<\/td>//' -e 's/\r//')
HOST=$(hostname -s)
IRCSAY=/usr/local/bin/ircsay
EMAIL=user@company.com

if [ -f /usr/local/nagios/libexec/check_nagios ]; then
	CHECK_PLUGIN_VERSION=$(/usr/local/nagios/libexec/check_nagios -h | sed -n '1p' | awk '{ print $1,$2 }')
else
	CHECK_PLUGIN_VERSION="Not Found"
fi

# Remove files from last run
if [ -f nagios-plugins-$PLUGIN_VERSION.tar.gz ]; then
        rm -f nagios-plugins-$PLUGIN_VERSION.tar.gz
fi

if [ -d nagios-plugins-$PLUGIN_VERSION ]; then
        rm -fr nagios-plugins-$PLUGIN_VERSION
fi

if [ "$CHECK_PLUGIN_VERSION" != "check_nagios v${PLUGIN_VERSION}" ]
then
        # Install plugins
        if wget http://assets.nagios.com/downloads/nagiosplugins/nagios-plugins-$PLUGIN_VERSION.tar.gz
        then
                tar zxf nagios-plugins-$PLUGIN_VERSION.tar.gz
                cd nagios-plugins-$PLUGIN_VERSION
                ./configure --with-nagios-user=nagios --with-nagios-group=nagios
                make && make install && echo "Plugins installed successfully!" || echo "Plugins failed to install!" && PLUGIN_SUCCESS=1
        fi

        if [ $PLUGIN_SUCCESS -eq 1 ]
        then
                echo "Nagios Plugins installed successfully!" | mail -s "[shell] Nagios plugins install successful on $HOST" $EMAIL
		if [ -f $IRCSAY ]; then
			( set +e; $IRCSAY "#nagios" "[shell] Nagios Plugins $PLUGIN_VERSION installed successfully on ${HOST}!" 2>/dev/null || true )
		fi
        else
                echo "Nagios Plugins failed to install" | mail -s "[shell] Nagios plugins install failed on $HOST" $EMAIL
		if [ -f $IRCSAY ]; then
			( set +e; $IRCSAY "#nagios" "[shell] Nagios Plugins $PLUGIN_VERSION failed to install on $HOST" 2>/dev/null || true )
		fi
        fi
else
        echo "Nagios Plugins v${PLUGIN_VERSION} already installed."
	if [ -f $IRCSAY ]; then
		( set +e; $IRCSAY "#nagios" "[shell] Nagios Plugins $PLUGIN_VERSION already installed on $HOST, quitting" 2>/dev/null || true )
	fi
fi
