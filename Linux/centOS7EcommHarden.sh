#!/bin/bash
#Hardening script for CentOS 7. Pretty identical and basic to the rest

# Add at the beginning of the script
LOG_FILE="/var/log/centos_harden_$(date +%Y%m%d_%H%M%S).log"
exec > >(tee -a "$LOG_FILE") 2>&1

# Check if running as root
if [ "$(id -u)" != "0" ]; then
   echo "This script must be run as root" 1>&2
   exit 1
fi

echo "Setting device banner"
cat > /etc/issue << EOF
LEGAL DISCLAIMER: This computer system is the property of Team 13 LLC. By using this system, you acknowledge and agree to comply with all applicable polcies, which include the acceptable use of Splunk. Your activities may be monitored, logged and audited for security purposes. Any unauthorized access or misuse may result in legal consequences. If you do not agree to abide by these terms, you must log off immediately!
If you do NOT wish to comply with these terms and conditions, you must LOG OFF IMMEDIATELY.
EOF

# Make sure we are pointing to the correct mirrors
cp /etc/yum.repos.d/CentOS-Base.repo{,.BACKUP}
cat >/etc/yum.repos.d/CentOS-Base.repo <<'EOF'
[base]
name=CentOS-$releasever - Base
baseurl=https://vault.centos.org/centos/$releasever/os/$basearch/
gpgcheck=1
gpgkey=file:///etc/pki/rpm-gpg/RPM-GPG-KEY-CentOS-7

[updates]
name=CentOS-$releasever - Updates
baseurl=https://vault.centos.org/centos/$releasever/updates/$basearch/
gpgcheck=1
gpgkey=file:///etc/pki/rpm-gpg/RPM-GPG-KEY-CentOS-7

[extras]
name=CentOS-$releasever - Extras
baseurl=https://vault.centos.org/centos/$releasever/extras/$basearch/
gpgcheck=1
gpgkey=file:///etc/pki/rpm-gpg/RPM-GPG-KEY-CentOS-7
EOF

# Install necessary tools and dependencies
echo "Installing necessary tools and dependencies..."
yum install -y curl wget nmap fail2ban iptables-services cron auditd


#
#   IPTables Rules
#
#

# Configure firewall rules using iptables
echo "Configuring firewall rules..."

# Flush existing rules
iptables -F
iptables -X

# Drop all traffic by default
iptables -P INPUT DROP
iptables -P OUTPUT DROP
iptables -P FORWARD DROP

# Allow limited incomming ICMP traffic and log packets that dont fit the rules
sudo iptables -A INPUT -p icmp --icmp-type echo-request -m length --length 0:192 -m limit --limit 1/s --limit-burst 5 -j ACCEPT
sudo iptables -A INPUT -p icmp --icmp-type echo-request -m length --length 0:192 -j LOG --log-prefix "Rate-limit exceeded: " --log-level 4
sudo iptables -A INPUT -p icmp --icmp-type echo-request -m length ! --length 0:192 -j LOG --log-prefix "Invalid size: " --log-level 4
sudo iptables -A INPUT -p icmp --icmp-type echo-reply -m limit --limit 1/s --limit-burst 5 -j ACCEPT
sudo iptables -A INPUT -p icmp -j DROP

# Allow outgoing ICMP traffic
sudo iptables -A OUTPUT -p icmp -j ACCEPT

# Allow traffic from existing/established connections
iptables -A INPUT -m conntrack --ctstate ESTABLISHED,RELATED -j ACCEPT
iptables -A OUTPUT -m conntrack --ctstate ESTABLISHED,RELATED -j ACCEPT

# Allow loopback traffic
iptables -A INPUT -i lo -j ACCEPT
iptables -A OUTPUT -o lo -j ACCEPT

# Allow incoming HTTP/HTTPS traffic
iptables -A INPUT -p tcp --dport 80 -j ACCEPT

# May not be needed if HTTPS is not scored
iptables -A INPUT -p tcp --dport 443 -j ACCEPT

# Allows outgoing HTTP/HTTPS traffic (for installing packages)
iptables -A OUTPUT -p tcp --dport 443 -j ACCEPT
iptables -A OUTPUT -p tcp --dport 80 -j ACCEPT

# Allow outgoing DNS traffic
iptables -A OUTPUT -p udp --dport 53 -j ACCEPT
iptables -A OUTPUT -p tcp --dport 53 -j ACCEPT

# Allow outgoing NTP traffic
iptables -A OUTPUT -p udp --dport 123 -j ACCEPT

# Allow Splunk forwarder traffic
iptables -A OUTPUT -p tcp --dport 9997 -j ACCEPT
iptables -A OUTPUT -p udp --dport 9997 -j ACCEPT #changed from -m to -p because -m only works if -p is defined
iptables -A INPUT -p tcp --sport 9997 -j ACCEPT
iptables -A INPUT -j LOG --log-prefix "IPTABLES-DROP:" --log-level 4
iptables -A OUTPUT -j LOG --log-prefix "IPTABLES-DROP:" --log-level 4

# Save iptables rules
mkdir /etc/iptables
iptables-save > /etc/iptables/rules.v4

# Disable firewalld
systemctl stop firewalld
systemctl disable firewalld

# Create backup directory if it doesn't exist
BACKUP_DIR="/etc/BacService/"
mkdir -p "$BACKUP_DIR"

# Backup network interface configurations (critical for security)
echo "Backing up network interface configurations..."
cp -R /etc/sysconfig/network-scripts/* "$BACKUP_DIR"    # Network interface configs
cp /etc/sysconfig/network "$BACKUP_DIR"                 # Network configuration
cp /etc/resolv.conf "$BACKUP_DIR"                       # DNS configuration
cp /etc/iptables/rules.v4 "$BACKUP_DIR"                 # A redundant backup for the iptable rules

# Backup service configurations
echo "Backing up service configurations..."
cp -R /var/www "$BACKUP_DIR"
cp -R /etc/httpd "$BACKUP_DIR"

# Set root password
while true; do
    echo "Enter new root password: "
    stty -echo
    read rootPass
    stty echo
    echo "Confirm root password: "
    stty -echo
    read confirmRootPass
    stty echo

    if [ "$rootPass" = "$confirmRootPass" ]; then
        break
    else
        echo "Passwords do not match. Please try again."
    fi
done

echo "root:$rootPass" | chpasswd

# Set sysadmin password
while true; do
    echo "Enter new sysadmin password: "
    stty -echo
    read sysadminPass
    stty echo
    echo "Confirm sysadmin password: "
    stty -echo
    read confirmSysadminPass
    stty echo

    if [ "$sysadminPass" = "$confirmSysadminPass" ]; then
        break
    else
        echo "Passwords do not match. Please try again."
    fi
done

echo "sysadmin:$sysadminPass" | chpasswd

#
#   Uninstall SSH, harden cron, final notes
#
#

# Uninstall SSH
echo "Uninstalling SSH..."
yum remove -y openssh-server

echo "restricting user creation to root only"
chmod 700 /usr/sbin/useradd
chmod 700 /usr/sbin/groupadd

# Harden cron
echo "Locking down Cron and AT permissions..."
touch /etc/cron.allow
chmod 600 /etc/cron.allow
awk -F: '{print $1}' /etc/passwd | grep -v root > /etc/cron.deny

touch /etc/at.allow
chmod 600 /etc/at.allow
awk -F: '{print $1}' /etc/passwd | grep -v root > /etc/at.deny

# Final steps
echo "Final steps..."
yum autoremove -y

echo "MAKE SURE YOU ENUMERATE!!!"
echo "Check for cronjobs, services on timers, etc, then update and upgrade the machine. THEN RESTART. It will update the kernel!!"

# Add a final output to help quickly search for rogue system accounts. This isn't exactly a sophisticated sweep, just something to help find some minor plants quicker.
echo "Looking for system accounts with permissions under 500. Double check these, but still make sure you check the /etc/shadow file for more accounts." 
echo "Permissions under or above 500 don't instantly mean an account is legit/malicious."
awk -F: '$3 >= 500 && $1 != "sysadmin" && $1 != "splunk" {print $1}' /etc/passwd | while read user; do
    echo "Found system account: $user"
    echo "To lock this account manually, run:"
    echo "  sudo usermod -L $user    # Lock the account"
    echo "  sudo usermod -s /sbin/nologin $user    # Prevent shell login"
    echo "---"
done
