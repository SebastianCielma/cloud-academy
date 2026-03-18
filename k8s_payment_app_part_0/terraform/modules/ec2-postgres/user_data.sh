#!/bin/bash
set -e

exec > >(tee /var/log/user-data.log|logger -t user-data -s 2>/dev/console) 2>&1

echo "Starting PostgreSQL installation and configuration..."

apt-get update
DEBIAN_FRONTEND=noninteractive apt-get install -y postgresql postgresql-contrib

sed -i "s/#listen_addresses = 'localhost'/listen_addresses = '*'/g" /etc/postgresql/*/main/postgresql.conf


echo "host    all             all             0.0.0.0/0               md5" >> /etc/postgresql/*/main/pg_hba.conf

systemctl restart postgresql

sudo -u postgres psql -c "CREATE DATABASE paymentdb;"
sudo -u postgres psql -c "CREATE USER postgres WITH ENCRYPTED PASSWORD '${db_password}';" || true
sudo -u postgres psql -c "ALTER ROLE postgres WITH ENCRYPTED PASSWORD '${db_password}';"
sudo -u postgres psql -c "GRANT ALL PRIVILEGES ON DATABASE paymentdb TO postgres;"
sudo -u postgres psql -d paymentdb -c "GRANT ALL ON SCHEMA public TO postgres;"

echo "PostgreSQL installed and configured successfully."

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
