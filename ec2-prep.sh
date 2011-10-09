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

# Make sure that we are root
if [ "$USER" != "root" ]; then
echo "root required; re-run with sudo";
  exit 1;
fi

# Install and configure unattended-upgrades. The system will
# automatically download, install and configure all packages, and reboot
# if necessary.
echo "Installing unattended-upgrades..."
aptitude install unattended-upgrades

# Back up the original configuration
mv /etc/apt/apt.conf.d/10periodic /etc/apt/apt.conf.d/10periodic.bkp
mv /etc/apt/apt.conf.d/50unattended-upgrades /etc/apt/apt.conf.d/50unattended-upgrades.bkp

echo "Configuring the unattended-upgrades package..."

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
aptitude safe-upgrade -y
apt-get -y update 
apt-get -y install tor tor-geoipdb

# Configure Tor
echo "Configuring Tor...";
cp /etc/tor/torrc /etc/tor/torrc.bkp

if [ $CONFIG == "bridge" ]; then
echo "Configuring Tor as a $CONFIG";
cat << EOF > $CONFIG_FILE
# Auto generated public Tor $CONFIG config file
Nickname ec2$CONFIG$RESERVATION
SocksPort 0
ORPort 443
BridgeRelay 1
AccountingStart week 1 10:00
AccountingMax 10 GB
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
DirPort 80
AccountingStart week 1 10:00
AccountingMax 10 GB
Exitpolicy reject *:*
EOF
fi

# XXX TODO
# Generally, we'll want to rm /var/lib/tor/* and remove all state from the system
echo "Restarting Tor...";
/etc/init.d/tor restart
sudo update-rc.d tor enable
echo "echo 'Tor Cloud Starting...'" > /etc/ec2-prep.sh

sudo reboot
