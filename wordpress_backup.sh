#!/bin/bash

# Database credentials
user="objured"
#password=""
host="localhost"
db_name="wp_myblog"

# Other options
backup_path=/root/.wp_backup/
date=$(date +"%d-%b-%Y")
backup_days="180"

# Create backup directory if it does not already exist
sudo mkdir -p "$backup_path"

# Set default file permissions
sudo umask 177

# Dump database into SQL file
sudo mysqldump -p --user=$user --host=$host $db_name > $backup_path/$db_name-$date.sql

# Delete files older than 30 days
sudo find $backup_path/* -mtime +$backup_days -exec rm {} \;