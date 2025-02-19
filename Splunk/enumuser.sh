#!/bin/bash

#NOT COMPLETED!!!!!!!!!!!!

# make sure to make the script executable before running
chmod +x "$0"

# Check if script is run as root

if [ "$EUID" -ne 0]; then
    echo "Please run this script as root!"
    exit 1

fi

OUTPUT_FILE="enumeration_results_$(endata +%Y%m%d_%H%M%S).txt" #results are dumped into enumeration_results

echo "=== Enumerating Users ===" | tee -a "$OUTPUT_FILE"
awk -F':' '{print $1}' /etc/passwd | tee -a "$OUTPUT_FILE"

#cat /etc/passwd | cut d: -f1
#TROUBLESHOOT: under this, cut -d: is not recognized

echo -e "\n=== Enumerating Cron Jobs ===" | tee -a "$OUTPUT_FILE"
#TROUBLESHOOT: cut: you must specifiy a list of bytes/characters or field 
#for user in $(cut -d: f1 /etc/passwd); do
for user in $(awk -F':' '{print $1}' /etc/passwd); do
    echo "Cron jobs for user: $user" | tee-a "$OUTPUT_FILE"
    crontab -l -u "$user" 2>/dev/null | tee -a "$OUTPUT_FI.E" || echo "No cron jobs for $user" | tee -a "$OUTPUT_FILE"
done
    #cronfile="/var/spool/cron/crontabs/$user"
    #if [ -f "$cronfile" ]; then
        #echo -e "\n[+] Cron jobs for user: $user"
        #cat "$cronfile"
    #fi
#done

#system wide cron jobs works as expected
echo -e "\n=== System-wide Cron Jobs ==="
cat /etc/crontab
cat /etc/cron.d/*
