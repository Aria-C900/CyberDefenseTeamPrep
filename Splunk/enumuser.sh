#!/bin/bash
# This script was made possible with the help of ChatGPT. 
# I have tested this on Splunk CLI running on Oracle Linux 9.5 on ProxMox, and it worked as expected.

# Make sure to make the script executable before running
chmod +x "$0"

# Check if script is run as root

if [ "$EUID" -ne 0 ]; then
    echo "Please run this script as root!"
    exit 1
fi

counter=1
while [[ -e "enum_results${counter}.txt" ]]; do #increments w/ each creation of file to compare past vs future
    ((counter++))
done

OUTPUT_FILE="enum_results${counter}.txt" #results are dumped into enum_results(1), (2) for each new creation of the file

# Enumerates users on the splunk CLI and puts them into enumeration_results_.txt + includes per-user cron jobs as well
echo "=== Enumerating Users ===" | tee -a "$OUTPUT_FILE"
awk -F':' '{print $1}' /etc/passwd | tee -a "$OUTPUT_FILE"

# Per-user cron jobs
echo -e "\n[+] Per-user Cron Jobs:" | tee -a "$OUTPUT_FILE"
for user in $(awk -F':' '{print $1}' /etc/passwd); do
    echo -e "\n[*] Cron jobs for user: $user" | tee -a "$OUTPUT_FILE"
    crontab -l -u "$user" 2>/dev/null | tee -a "$OUTPUT_FILE" || echo "No cron jobs for $user" | tee -a "$OUTPUT_FILE"
done



# System-wide cron jobs
echo -e "\n[+] System-Wide Cron Jobs (/etc/crontab and /etc/cron.d/*):" | tee -a "$OUTPUT_FILE"
cat /etc/crontab 2>/dev/null | tee -a "$OUTPUT_FILE"
ls -l /etc/cron.d 2>/dev/null | tee -a "$OUTPUT_FILE"


# Tells user where to find the full results
echo "Results saved to $OUTPUT_FILE"
