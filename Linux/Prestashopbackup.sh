#!/bin/bash

# watch the prestastop, may go down or be changed in some way

#!/bin/bash
# backup_php.sh
#
# Script to backup a PHP file
# Usage: ./backup_php.sh /path/to/source.php /path/to/backup_directory
# NOTE: ROUGH DRAFT


#






# Check for proper arguments

if [ "$#" -ne 2 ]; then
    echo "Usage: $0 <source_php_file> <backup_directory>"
    exit 1
fi

SOURCE_FILE="$1"
BACKUP_DIR="$2"

# Verify that the source PHP file exists
if [ ! -f "$SOURCE_FILE" ]; then
    echo "Error: Source file $SOURCE_FILE not found!"
    exit 1
fi

# Create backup directory if it doesn't exist
if [ ! -d "$BACKUP_DIR" ]; then
    echo "Backup directory $BACKUP_DIR does not exist. Creating..."
    mkdir -p "$BACKUP_DIR"
fi

# Generate a timestamp for the backup file
TIMESTAMP=$(date +%Y%m%d_%H%M%S)

# Construct the backup file name
BASENAME=$(basename "$SOURCE_FILE")
BACKUP_FILE="${BACKUP_DIR}/${BASENAME}_${TIMESTAMP}.bak"

# Copy the source PHP file to the backup location
cp "$SOURCE_FILE" "$BACKUP_FILE"

# Check if the backup succeeded
if [ $? -eq 0 ]; then
    echo "Backup successful: $BACKUP_FILE"
else
    echo "Backup failed!"
    exit 1
fi
