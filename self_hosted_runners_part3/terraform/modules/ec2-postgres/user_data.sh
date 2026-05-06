#!/bin/bash
set -e

exec > >(tee /var/log/user-data.log|logger -t user-data -s 2>/dev/console) 2>&1


DB_PASSWORD="${db_password}"
APP_CIDR="$${app_cidr:-10.0.0.0/16}" 

export DEBIAN_FRONTEND=noninteractive
apt-get update
apt-get install -y postgresql postgresql-contrib


sed -i "s/#listen_addresses = 'localhost'/listen_addresses = '*'/g" /etc/postgresql/*/main/postgresql.conf


echo "host    paymentdb       payment_user    $APP_CIDR        scram-sha-256" >> /etc/postgresql/*/main/pg_hba.conf

systemctl restart postgresql

sudo -u postgres psql -c "CREATE DATABASE paymentdb;"
sudo -u postgres psql -c "CREATE USER payment_user WITH ENCRYPTED PASSWORD '$DB_PASSWORD';"

sudo -u postgres psql -c "GRANT ALL PRIVILEGES ON DATABASE paymentdb TO payment_user;"
sudo -u postgres psql -d paymentdb -c "GRANT ALL ON SCHEMA public TO payment_user;"

echo "PostgreSQL installed and configured securely."

mkdir -p /var/backups/postgresql

cat << 'EOF' > /usr/local/bin/db-backup.sh
#!/bin/bash
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
BACKUP_DIR="/var/backups/postgresql"
FILE="$BACKUP_DIR/paymentdb_backup_$TIMESTAMP.sql"

su - postgres -c "pg_dump paymentdb > $FILE"

find $BACKUP_DIR -name "paymentdb_backup_*.sql" -type f -mtime +7 -delete
EOF

chmod +x /usr/local/bin/db-backup.sh

(crontab -l 2>/dev/null; echo "0 2 * * * /usr/local/bin/db-backup.sh >> /var/log/db-backup.log 2>&1") | crontab -

echo "User data execution completed"