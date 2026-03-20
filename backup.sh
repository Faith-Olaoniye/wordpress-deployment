#!/bin/bash

# ===========================================
# backup.sh
# Creates a MySQL database backup and uploads it to an S3 bucket for safe storage.
# Run this script from the EC2 instance.
# ===========================================

# ---- Configuration ----
# Set these values to match your own setup.
# CONTAINER_NAME: the name Docker gives your MySQL container
# DB_NAME: the database to back up (matches MYSQL_DATABASE in .env)
# S3_BUCKET: the name of S3 bucket from Part 1

CONTAINER_NAME="wordpress-deployment-db-1"
DB_NAME="wordpress"
S3_BUCKET="wordpress-backup-faitholaoniye-2026"
BACKUP_DIR="/tmp"

# ---- Step 1: Generate a timestamped filename ----
# We include the date and time in the filename so every backup is unique and you can tell exactly when it was made.
# Format: backup-YYYY-MM-DD-HHMM.sql
# Example: backup-2026-03-17-1430.sql

TIMESTAMP=$(date +"%Y-%m-%d-%H%M")
BACKUP_FILE="$BACKUP_DIR/backup-$TIMESTAMP.sql"

echo "Starting backup: $BACKUP_FILE"

# ---- Step 2: Dump the database ----
# The "docker exec" is used to run the mysqldump command
# INSIDE the running MySQL container.
# mysqldump exports the entire database as a .sql file.
# The -p flag reads the password from the environment variable.

echo "Dumping database..."

docker exec $CONTAINER_NAME \
    mysqldump -u root -p"$(grep MYSQL_ROOT_PASSWORD /home/ubuntu/.env | cut -d '=' -f2)" \
    $DB_NAME > $BACKUP_FILE

echo "Database dumped to $BACKUP_FILE"

# ---- Step 3: Upload the backup to S3 ----
# The AWS CLI sends the backup file to your S3 bucket.
# The s3:// prefix tells the CLI this is an S3 path, not a local folder path.

echo "Uploading backup to S3..."

aws s3 cp $BACKUP_FILE s3://$S3_BUCKET/backups/

echo "Backup uploaded to: s3://$S3_BUCKET/backups/backup-$TIMESTAMP.sql"

# ---- Step 4: Remove the local backup file ----
# Once it is safely uploaded to S3 we don't need the local copy anymore. Removing it keeps the server tidy and prevents the /tmp folder from filling up over time.

echo "Cleaning up local backup file..."
rm $BACKUP_FILE 
echo "Local file removed."

# ---- All done! ----
echo ""
echo "============================================"
echo " Backup complete!"
echo " File: s3://$S3_BUCKET/backups/backup-$TIMESTAMP.sql"
echo "============================================"