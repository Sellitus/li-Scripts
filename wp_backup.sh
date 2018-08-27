#!/bin/bash

# NOTE: You will need to create a /root/.my.cnf with the mysql username and password first.
# FORMAT:
#
# [mysqldump]
# user=<username>
# password=<password>
#
# Now add a crontab entry for root to backup every Sunday at 5 AM 
# 0 5 * * 7 sudo bash /root/li-scripts/wp_backup.sh 
# 
# OPTIONAL: Setup vmtouch to cache wordpress file directory in RAM
# vmtouch -dlv /var/www/html/
# vmtouch -dlv /var/lib/apache2/
# vmtouch -dlv /var/lib/mysql/
# vmtouch -dlv /etc/apache2/
# 



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

# Set default file permissions (not for root use)
# umask 177

# Dump database into SQL file
sudo mysqldump --host=$host $db_name > $backup_path/$db_name-$date.sql

# Delete files older than 30 days
sudo find $backup_path/* -mtime +$backup_days -exec rm {} \;
