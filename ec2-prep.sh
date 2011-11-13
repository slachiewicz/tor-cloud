#!/bin/bash
# ec2-prep by: Jacob Appelbaum
# git://git.torproject.org/ioerror/tor-cloud.git
# This is the code to run on an Ubuntu machine to prep it as a relay, bridge or
# private bridge
#
USER="`whoami`";
DISTRO="`lsb_release -c|cut -f2`";
SOURCES="/etc/apt/sources.list";
CONFIG="$1";
CONFIG_FILE="/etc/tor/torrc";
RESERVATION="`curl -m 5 http://169.254.169.254/latest/meta-data/reservation-id | sed 's/-//'`";
PERIODIC="/etc/apt/apt.conf.d/10periodic"
UNATTENDED_UPGRADES="/etc/apt/apt.conf.d/50unattended-upgrades"
IPTABLES_RULES="/etc/iptables.rules"
NETWORK="/etc/network/interfaces"

# Make sure that we are root
if [ "$USER" != "root" ]; then
echo "root required; re-run with sudo";
  exit 1;
fi

# Get the latest package updates
echo "Updating the system..."
aptitude update
aptitude -y safe-upgrade

# Configure unattended-upgrades. The system will automatically download,
# install and configure all packages, and reboot if necessary.
echo "Configuring the unattended-upgrades package..."

# Back up the original configuration
mv /etc/apt/apt.conf.d/10periodic /etc/apt/apt.conf.d/10periodic.bkp
mv /etc/apt/apt.conf.d/50unattended-upgrades /etc/apt/apt.conf.d/50unattended-upgrades.bkp

# Choose what to upgrade in 10periodic
cat << EOF > $PERIODIC
# Update the package list, download, and install available upgrades
# every day. The local archive is cleaned once a week.
APT::Periodic::Enable "1";
APT::Periodic::Update-Package-Lists "1";
APT::Periodic::Download-Upgradeable-Packages "1";
APT::Periodic::AutocleanInterval "7";
APT::Periodic::Unattended-Upgrade "1";
EOF

# Enable automatic package updates in 50unattended-upgrades
cat << EOF > $UNATTENDED_UPGRADES
// Automatically upgrade packages from these (origin, archive) pairs
Unattended-Upgrade::Allowed-Origins {
    "Ubuntu lucid";
	"Ubuntu lucid-security";
	"Ubuntu lucid-updates";
	"Tor lucid";
	"Tor experimental-lucid";
};

// Automatically reboot *WITHOUT CONFIRMATION* if the file
// /var/run/reboot-required is found after the upgrade
Unattended-Upgrade::Automatic-Reboot "true";
EOF

# Configure iptables to redirect traffic to port 443 to port 9001
# instead, and make that configuration stick.
echo "Configuring iptables..."
cat << EOF > $IPTABLES_RULES
*nat
:PREROUTING ACCEPT [0:0]
:POSTROUTING ACCEPT [77:6173]
:OUTPUT ACCEPT [77:6173]
-A PREROUTING -i eth0 -p tcp -m tcp --dport 443 -j REDIRECT --to-ports 9001 
COMMIT
EOF

mv /etc/network/interfaces /etc/network/interfaces.bkp
cat << EOF > $NETWORK
# The loopback network interface
auto lo
iface lo inet loopback

# The primary network interface
auto eth0
iface eth0 inet dhcp
  pre-up iptables-restore < /etc/iptables.rules
EOF

# Choose how to configure Tor
case "$CONFIG" in
   "bridge" ) echo "selecting $CONFIG config...";;
   "privatebridge" ) echo "selecting $CONFIG config...";;
   "middlerelay" ) echo "selecting $CONFIG config...";;
   * )
echo "You did not select a proper configuration: $CONFIG";
echo "Please try the following examples: ";
echo "$0 bridge";
echo "$0 privatebridge";
echo "$0 middlerelay";
exit 2;
    ;;
esac

# Add deb.torproject.org to /etc/apt/sources.list
echo "Adding Tor's repo for $DISTRO...";
cat << EOF >> $SOURCES
deb http://deb.torproject.org/torproject.org $DISTRO main
deb http://deb.torproject.org/torproject.org experimental-$DISTRO main
EOF

# Install Tor's GPG key
echo "Installing Tor's gpg key...";
gpg --keyserver keys.gnupg.net --recv 886DDD89
gpg --export A3C4F0F979CAA22CDBA8F512EE8CBC9E886DDD89 | apt-key add -

# Install Tor
echo "Installing Tor...";
aptitude update
aptitude -y install tor tor-geoipdb

# Configure Tor
echo "Configuring Tor...";
cp /etc/tor/torrc /etc/tor/torrc.bkp

if [ $CONFIG == "bridge" ]; then
echo "Configuring Tor as a $CONFIG";
cat << EOF > $CONFIG_FILE
# Auto generated public Tor $CONFIG config file

# A unique handle for your server.
Nickname ec2$CONFIG$RESERVATION

# Set "SocksPort 0" if you plan to run Tor only as a server, and not
# make any local application connections yourself.
SocksPort 0

# What port to advertise for Tor connections.
ORPort 443

# Listen on a port other than the one advertised in ORPort (that is,
# advertise 443 but bind to 9001).
ORListenAddress 0.0.0.0:9001

# Start Tor as a bridge.
BridgeRelay 1

# Never send or receive more than 10GB of data per week. The accounting
# period runs from 10 AM on the 1st day of the week (Monday) to the same
# day and time of the next week.
AccountingStart week 1 10:00
AccountingMax 10 GB

# Running a bridge relay just passes data to and from the Tor network --
# so it shouldn't expose the operator to abuse complaints.
Exitpolicy reject *:*
EOF
fi

if [ $CONFIG == "private-bridge" ]; then
echo "Configuring Tor as a $CONFIG";
cat << EOF > $CONFIG_FILE
# Auto generated public Tor $CONFIG config file
Nickname ec2$CONFIG$RESERVATION
SocksPort 0
ORPort 443
ORListenAddress 0.0.0.0:9001
BridgeRelay 1
PublishServerDescriptor 0
AccountingStart week 1 10:00
AccountingMax 10 GB
Exitpolicy reject *:*
EOF
fi

if [ $CONFIG == "middle-relay" ]; then
echo "Configuring Tor as a $CONFIG";
cat << EOF > $CONFIG_FILE
# Auto generated public Tor $CONFIG config file
Nickname ec2$CONFIG$RESERVATION
SocksPort 0
ORPort 443
ORListenAddress 0.0.0.0:9001
DirPort 80
AccountingStart week 1 10:00
AccountingMax 10 GB
Exitpolicy reject *:*
EOF
fi

# XXX TODO
# Generally, we'll want to rm /var/lib/tor/* and remove all state from the system
#
# We're done; tell the user and then reboot the system
echo "Done configuring the system, will reboot"
echo "Your system has been configured as a Tor bridge, see https://cloud.torproject.org/ for more info" > /etc/ec2-prep.sh
reboot
