#!/bin/bash
# deb10_bind_dns_config.sh

# Script is to configure the Debian BIND DNS server within the Internal zone to allow only DNS traffic to the internet via PAN-OS 11 CLI

# # NOTE: This config is to ensure that ONLY DNS traffic FROM debian 10 is permitted outbound. 

# This script was created with the help of ChatGPT.


# Feb 2025

printf "Starting DNS configuration script\n"

printf "Starting DNS configuration script\n"

# Fixed IP for Debian 10 handling BIND DNS
dns_ip="172.20.240.20"

# Create a temporary configuration file with the necessary commands
config_file="dns_config_temp.txt"

# Begin CLI commands
echo "set cli scripting-mode on" > $config_file
echo "configure" >> $config_file

# Define the address object for the Debian BIND DNS server
echo "set address internal-debian-bind-dns ip-netmask ${dns_ip}/32" >> $config_file

# Create a security policy to allow only DNS traffic from the Debian server
echo "set rulebase security rules \"Allow-Debian-BindDNS\" description \"Allow only BIND DNS traffic from Debian in Internal zone to the Internet\"" >> $config_file
echo "set rulebase security rules \"Allow-Debian-BindDNS\" from \"Internal\"" >> $config_file
echo "set rulebase security rules \"Allow-Debian-BindDNS\" to \"Untrust\"" >> $config_file
echo "set rulebase security rules \"Allow-Debian-BindDNS\" source internal-debian-bind-dns" >> $config_file
echo "set rulebase security rules \"Allow-Debian-BindDNS\" destination any" >> $config_file
echo "set rulebase security rules \"Allow-Debian-BindDNS\" application dns" >> $config_file
echo "set rulebase security rules \"Allow-Debian-BindDNS\" service application-default" >> $config_file
echo "set rulebase security rules \"Allow-Debian-BindDNS\" action allow" >> $config_file
echo "set rulebase security rules \"Allow-Debian-BindDNS\" log-end yes" >> $config_file

# Commit the changes
echo "commit" >> $config_file

# Push the configuration to the firewall via SSH
# (Replace the management IP and admin credentials as needed)
ssh -T -o HostKeyAlgorithms=+ssh-rsa -o PubKeyAuthentication=no -o PasswordAuthentication=yes admin@172.20.242.150 < $config_file

# Optionally, remove the temporary configuration file
rm $config_file

printf "DNS configuration script completed.\n"
exit 0
