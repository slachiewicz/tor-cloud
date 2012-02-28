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
GPGKEY="/etc/apt/trusted.gpg.d/tor.asc"

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
#gpg --keyserver keys.gnupg.net --recv 886DDD89
#gpg --export A3C4F0F979CAA22CDBA8F512EE8CBC9E886DDD89 | apt-key add -
cat << EOF > $GPGKEY
-----BEGIN PGP PUBLIC KEY BLOCK-----
Version: GnuPG v1.4.11 (GNU/Linux)

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
yIJpnL6TsA5uFqUosz2rOPKeeDOtruSo490PTA==
=MGuX
-----END PGP PUBLIC KEY BLOCK-----
EOF
apt-key add $GPGKEY

# Install Tor and arm
echo "Installing Tor...";
aptitude update
aptitude -y install tor tor-geoipdb tor-arm

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
ExitPolicy reject *:*
EOF
echo "Done configuring the system, will reboot"
echo "Your system has been configured as a Tor bridge, see https://cloud.torproject.org/ for more info" > /etc/ec2-prep.sh
fi

if [ $CONFIG == "privatebridge" ]; then
echo "Configuring Tor as a $CONFIG";
cat << EOF > $CONFIG_FILE
# Auto generated public Tor $CONFIG config file

# A unique handle for your server.
Nickname ec2priv$RESERVATION

# Set "SocksPort 0" if you plan to run Tor only as a server, and not
# make any local application connections yourself.
SocksPort 0

# What port to advertise for Tor connections.
ORPort 443

# Listen on a port other than the one advertised in ORPort (that is,
# advertise 443 but bind to 9001).
ORListenAddress 0.0.0.0:9001

# Start Tor as a private bridge.
BridgeRelay 1
PublishServerDescriptor 0

# Never send or receive more than 10GB of data per week. The accounting
# period runs from 10 AM on the 1st day of the week (Monday) to the same
# day and time of the next week.
AccountingStart week 1 10:00
AccountingMax 10 GB

# Running a bridge relay just passes data to and from the Tor network --
# so it shouldn't expose the operator to abuse complaints.
ExitPolicy reject *:*
EOF
echo "Done configuring the system, will reboot"
echo "Your system has been configured as a private Tor bridge, see https://cloud.torproject.org/ for more info" > /etc/ec2-prep.sh
fi

# XXX TODO
# Generally, we'll want to rm /var/lib/tor/* and remove all state from the system
#
# We're done; tell the user and then reboot the system
reboot
