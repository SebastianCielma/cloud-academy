#!/bin/bash
BACKUP_DIR="/var/backups/postgresql"
TIMESTAMP=$(date +"%Y%m%d_%H%M%S")
FILENAME="paymentdb_backup_${TIMESTAMP}.sql"

sudo -u postgres pg_dump paymentdb > "${BACKUP_DIR}/${FILENAME}"