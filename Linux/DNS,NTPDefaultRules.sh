#!/bin/bash


# Check if running as root
if [ "$(id -u)" != "0" ]; then
   echo "This script must be run as root" 1>&2
   exit 1
fi


# Install necessary tools and dependencies
echo "Installing necessary tools and dependencies..."
apt install -y curl wget nmap iptables-persistent auditd


echo "Setting device banner"
cat > /etc/issue << EOF
LEGAL DISCLAIMER: This computer system is the property of Team 17 LLC. By using this system, you acknowledge and agree to comply with all applicable polcies, which include the acceptable use of Splunk. Your activities may be monitored, logged and audited for security purposes. Any unauthorized access or misuse may result in legal consequences. If you do not agree to abide by these terms, you must log off immediately!
If you do NOT wish to comply with these terms and conditions, you must LOG OFF IMMEDIATELY.
EOF

#
#   IPTables Rules
#
#

# Configure firewall rules using iptables
echo "Configuring firewall rules..."

#Flush rules
iptables -F
iptables -X

# Drop all traffic by default
iptables -P INPUT DROP
iptables -P OUTPUT DROP
iptables -P FORWARD DROP

#Allow limited incomming ICMP traffic and log packets that dont fit the rules
sudo iptables -A INPUT -p icmp --icmp-type echo-request -m length --length 0:192 -m limit --limit 1/s --limit-burst 5 -j ACCEPT
sudo iptables -A INPUT -p icmp --icmp-type echo-request -m length --length 0:192 -j LOG --log-prefix "ICMP - Rate Limit Exceeded: " --log-level 4
sudo iptables -A INPUT -p icmp --icmp-type echo-request -m length ! --length 0:192 -j LOG --log-prefix "ICMP - Invalid Size: " --log-level 4
sudo iptables -A INPUT -p icmp --icmp-type echo-reply -m limit --limit 1/s --limit-burst 5 -j ACCEPT
sudo iptables -A INPUT -p icmp -j DROP

#Allow outgoing ICMP traffic
sudo iptables -A OUTPUT -p icmp -j ACCEPT

#Allow traffic from exisiting/established connections
iptables -A INPUT -m conntrack --ctstate ESTABLISHED,RELATED -j ACCEPT
iptables -A OUTPUT -m conntrack --ctstate ESTABLISHED,RELATED -j ACCEPT

#Allow to install
iptables -A OUTPUT -p tcp --dport 80 -j ACCEPT
iptables -A OUTPUT -p tcp --dport 443 -j ACCEPT

#Allow limited incomming DNS traffic to prevent DNS floods (change the limit as needed)
iptables -A INPUT -p udp --dport 53 -m limit --limit 3/sec --limit-burst 10 -j ACCEPT
iptables -A INPUT -p tcp --dport 53 -m limit --limit 3/sec --limit-burst 10 -j ACCEPT
iptables -A INPUT -p udp --dport 53 -j LOG --log-prefix "DNS - UDP Rate Limit Exceeded: " --log-level 4
iptables -A INPUT -p tcp --dport 53 -j LOG --log-prefix "DNS - TCP Rate Limit Exceeded: " --log-level 4

#Used to prevent double logging for dropeed DNS packets
iptables -A INPUT -p udp --dport 53 -j DROP 
iptables -A INPUT -p tcp --dport 53 -j DROP

#Allow outgoing DNS traffic
iptables -A OUTPUT -p tcp --dport 53 -j ACCEPT
iptables -A OUTPUT -p udp --dport 53 -j ACCEPT

#Allow NTP traffic
iptables -A INPUT -p udp --dport 123 -j ACCEPT
iptables -A OUTPUT -p udp --dport 123 -j ACCEPT

#Allow traffic on Splunk ports
iptables -A INPUT -p tcp --dport 9997 -j ACCEPT
iptables -A OUTPUT -p tcp --dport 9997 -j ACCEPT
iptables -A OUTPUT -p tcp --dport 8000 -j ACCEPT

#Allow loopback traffic
iptables -A INPUT -i lo -j ACCEPT
iptables -A OUTPUT -o lo -j ACCEPT
iptables -A FORWARD -i lo -j ACCEPT
iptables -A FORWARD -o lo -j ACCEPT

# Log dropped packets
iptables -A INPUT -j LOG --log-prefix "IPTABLES-DROP:" --log-level 4
iptables -A OUTPUT -j LOG --log-prefix "IPTABLES-DROP:" --log-level 4

mkdir /etc/iptables
iptables-save > /etc/iptables/rules.v4

#
#  NTP Configuration
#
#

# Configure NTP
echo "Configuring NTP..."
cat > /etc/ntp.conf << EOF
driftfile /var/lib/ntp/ntp.drift

restrict default nomodify notrap noquery
restrict 127.0.0.1
restrict ::1

pool 0.debian.pool.ntp.org iburst
pool 1.debian.pool.ntp.org iburst
pool 2.debian.pool.ntp.org iburst
pool 3.debian.pool.ntp.org iburst

disable monitor
EOF

systemctl restart ntp


# Password Management
echo "Setting new passwords..."

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

echo "Uninstalling SSH..."
apt remove --purge openssh-server -y

echo "Uninstalling FTP..."
systemctl stop proftpd
apt remove --purge proftpd -y

echo "Uninstalling apache2..."
systemctl stop apache2
apt remove --purge apache2 -y

echo "Removing unnecessary users and their home directories..."
userdel -r promon
userdel -r produde
userdel -r proscrape
userdel -r ftp
userdel -r proftpd

echo "Removing games directory..."
rm -rf /usr/games

echo "Removing README file..."
rm -f /etc/sudoers.d/README

echo "restricting user and group creation to root only"
chmod 700 /usr/sbin/useradd
chmod 700 /usr/sbin/groupadd

echo "Creating backups..."
mkdir /etc/conf_services && chmod 600 /etc/conf_services
tar -czf /etc/conf_services/bind.tar.gz -C /etc/bind .

#harden cron
echo "Locking down Cron and AT permissions..."
touch /etc/cron.allow
chmod 600 /etc/cron.allow
awk -F: '{print $1}' /etc/passwd | grep -v root > /etc/cron.deny

touch /etc/at.allow
chmod 600 /etc/at.allow
awk -F: '{print $1}' /etc/passwd | grep -v root > /etc/at.deny


# Final steps
echo "Final steps..."
apt autoremove -y

echo "MAKE SURE YOU ENUMERATE!!!"
echo "Check for cronjobs, services on timers, etc, then update and upgrade the machine. THEN RESTART. It will update the kernel!!"

# Add a final output to help quickly search for rogue system accounts. This isn't exactly a sophisticated sweep, just something to help find some minor plants quicker.
echo "Looking for system accounts with permissions under 500. Double check these, but still make sure you check the /etc/shadow file for more accounts." 
echo "Permissions under or above 500 don't instantly mean an account is legit/malicious."
awk -F: '$3 >= 500 && $1 != "sysadmin" {print $1}' /etc/passwd | while read user; do
    echo "Found system account: $user"
    echo "To lock this account manually, run:"
    echo "  sudo usermod -L $user    # Lock the account"
    echo "  sudo usermod -s /sbin/nologin $user    # Prevent shell login"
    echo "---"
done
