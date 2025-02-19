#!/bin/bash

# makes script executable

chmod +x enumuser.sh

# Check if script is run as root

if [ "$EUID" -ne 0]; then
    echo "Please run this script as root!"
    exit 1

fi

echo "=== Enumerating Users ==="
cat /etc/passwd | cut d: -f1

echo -e "\n=== Enumerating Cron Jobs ==="
for user in $(cut -d: f1 /etc/passwd); do
    cronfile="/var/spool/cron/crontabs/$user"
    if [ -f "$cronfile" ]; then
        echo -e "\n[+] Cron jobs for user: $user"
        cat "$cronfile"
    fi
done

echo -e "\n=== System-wide Cron Jobs ==="
cat /etc/crontab
cat /etc/cron.d/*
