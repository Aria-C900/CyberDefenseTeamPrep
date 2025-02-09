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
LEGAL DISCLAIMER: This computer system is the property of Team [team number] LLC. By using this system, all users acknowledge notice of, and agree to comply with, the Acceptable User of Information Technology Resources Polity (AUP). 
By using this system, you consent to these terms and conditions. Use is also consent to monitoring, logging, and use of logging to prosecute abuse. 
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

#Allow loopback traffic
iptables -A INPUT -i lo -j ACCEPT
iptables -A OUTPUT -o lo -j ACCEPT
iptables -A FORWARD -i lo -j ACCEPT
iptables -A FORWARD -o lo -j ACCEPT

# Log dropped packets
iptables -A INPUT -j LOG --log-prefix "IPTABLES-DROP:" --log-level 4
iptables -A OUTPUT -j LOG --log-prefix "IPTABLES-DROP:" --log-level 4

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

# Uninstall SSH
echo "Uninstalling SSH..."
apt remove --purge openssh-server -y

echo "restricting user creation to root only"
chmod 700 /usr/sbin/useradd
chmod 700 /usr/sbin/groupadd#harden cron

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
