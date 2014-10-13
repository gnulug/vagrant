NAGIOS_SERVER_IP=""
apt-get install -y --no-install-recommends nagios-nrpe-server nagios-plugins-standard nagios-nrpe-plugin &&
echo -e "\nInstalled: nagios-nrpe-server nagios-plugins-standard nagios-nrpe-plugin\n"

if [ -d /etc/nagios-plugins/ ]; then
	rm -rf /etc/nagios-plugins/
fi

ufw allow from $NAGIOS_SERVER_IP to any port 5666 proto tcp &&
echo "Firewall: Add rule allowing connections from Nagios server: $NAGIOS_SERVER_IP"

service nagios-nrpe-server restart

if [ $? -eq 0 ]; then
	echo "NRPE started successfully!"
else
	echo "NRPE failed to start!"
fi
