#!/bin/bash

#NOT COMPLETED!!!!!!!!!!!!

# make sure to make the script executable before running
# sudo chmod +x enumuser.sh

# Check if script is run as root

if [ "$EUID" -ne 0]; then
    echo "Please run this script as root!"
    exit 1

fi

echo "=== Enumerating Users ==="
cat /etc/passwd | cut d: -f1
#TROUBLESHOOT: under this, cut -d: is not recognized

echo -e "\n=== Enumerating Cron Jobs ==="
#TROUBLESHOOT: cut: you must specifiy a list of bytes/characters or field 
for user in $(cut -d: f1 /etc/passwd); do
    cronfile="/var/spool/cron/crontabs/$user"
    if [ -f "$cronfile" ]; then
        echo -e "\n[+] Cron jobs for user: $user"
        cat "$cronfile"
    fi
done

#system wide cron jobs works as expected
echo -e "\n=== System-wide Cron Jobs ==="
cat /etc/crontab
cat /etc/cron.d/*
