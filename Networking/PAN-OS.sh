#!/bin/bash
# This script applies the configuration changes using the CLI tool.
# Replace "cli" with the actual command if different.
# Rough draft w/ AI look over, special thanks to Ronnie!

# note: public facing ips are your team number + 20
cli <<'EOF'
configure
delete address "Google DNS"

rename address "Internal" to "Internal NetID"
rename address "Public" to "Public NetID"
rename address "User" to "User NetID"

set address "Cloudflare DNS" ip-netmask 1.1.1.1/32
set address "2019 Docker" ip-netmask 172.20.240.10/32
set address "Debian" ip-netmask 172.20.240.20/32
set address "Internal Gateway" ip-netmask 172.20.240.254/32
set address "Ubuntu Srvr" ip-netmask 172.20.242.10/32
set address "2019 AD" ip-netmask 172.20.242.100/32
set address "User Gateway" ip-netmask 172.20.242.254/32
set address "Splunk" ip-netmask 172.20.241.20/32
set address "CentOS" ip-netmask 172.20.241.30/32
set address "Fedora" ip-netmask 172.20.241.40/32
set address "Windows 10" ip-netmask 172.31.37.5

commit
EOF
