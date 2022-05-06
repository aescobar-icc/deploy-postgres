#!/bin/bash

if [[ "$#" -ne 2 ]]; then
	echo "Usage: $0 <database_name> <path_backup_file>"
	exit 1
fi
database_name=$1
path_backup_file=$2
port=5433


# -e
# --exit-on-error
# -c to clean the database
# -U to force a user
# -d $1 the database
# -v verbose mode, don't know why
# $2 the location backup file
# -W to force asking for the password to the user (postgres)


PGPASSWORD=$POSTGRES_PASSWORD pg_restore --exit-on-error -h localhost -p $port -c -U admin -d $database_name -v $path_backup_file

# CREATE ROLE postgres;
# CREATE ROLE altouch_root
# apply only script