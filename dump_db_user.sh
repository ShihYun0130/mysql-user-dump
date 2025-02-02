#!/bin/bash

# Check if all required arguments are passed
if [ $# -lt 4 ]; then
    echo "Usage: $0 <mysql_user> <mysql_host> <mysql_port> <mode>"
    echo "Modes: create_users | grant_privileges | revoke"
    exit 1
fi

# Extract MySQL credentials and mode from the command-line arguments
MYSQL_USER=$1
MYSQL_HOST=$2
MYSQL_PORT=$3
MODE=$4

# Prompt for MySQL password only once
echo "Enter password for MySQL user '${MYSQL_USER}': "
read -s MYSQL_PASS
echo

# Set the MySQL password as an environment variable to avoid the command-line warning
export MYSQL_PWD="$MYSQL_PASS"

# Determine the output file based on the mode
TIMESTAMP=$(date '+%Y-%m-%d %H:%M:%S')
case "$MODE" in
    create_users)
        OUTPUT_FILE="create_users.sql"
        cat <<EOF > $OUTPUT_FILE
-- User creation statements
-- Dumped at $TIMESTAMP
EOF
        ;;
    grant_privileges)
        OUTPUT_FILE="grant_privileges.sql"
        cat <<EOF > $OUTPUT_FILE
-- User grant statements
-- Dumped at $TIMESTAMP
EOF
        ;;
    revoke)
        OUTPUT_FILE="revoke_forbidden.sql"
        cat <<EOF > $OUTPUT_FILE
-- User creation, grants, and privilege revocations
-- Dumped at $TIMESTAMP
EOF
        ;;
    *)
        echo "Invalid mode. Use 'create_users', 'grant_privileges', or 'revoke'."
        unset MYSQL_PWD
        exit 1
        ;;
esac

# Fetch the list of users and hosts, including password hashes in hexadecimal format
USER_QUERY="SELECT user, host, authentication_string, HEX(authentication_string) AS auth_string_hex, plugin 
            FROM mysql.user 
            WHERE user NOT IN ('root', 'mysql.sys', 'mysql.session', 'mysql.infoschema', 'admin');"

# Execute the query and process each user
mysql -h$MYSQL_HOST -P$MYSQL_PORT -u$MYSQL_USER --silent --skip-column-names -e "$USER_QUERY" | while read -r user host auth_string auth_string_hex plugin; do
    # Check if the MySQL command succeeded
    if [ $? -ne 0 ]; then
        echo "Error retrieving user data for '${user}'@'${host}'. Exiting."
        exit 1
    fi

    # Handle user creation statements
    if [ "$MODE" == "create_users" ]; then
        # Add user header to the file
        echo "-- Create user '${user}'@'${host}'" >> $OUTPUT_FILE
        if [ "$plugin" = "caching_sha2_password" ] && [ -n "$auth_string_hex" ]; then
            echo "CREATE USER IF NOT EXISTS '${user}'@'${host}' IDENTIFIED WITH 'caching_sha2_password' AS 0x${auth_string_hex} REQUIRE NONE PASSWORD EXPIRE DEFAULT ACCOUNT UNLOCK;" >> $OUTPUT_FILE
        elif [ "$plugin" = "mysql_native_password" ] && [ -n "$auth_string" ]; then
            echo "CREATE USER IF NOT EXISTS '${user}'@'${host}' IDENTIFIED WITH 'mysql_native_password' AS '${auth_string}' REQUIRE NONE PASSWORD EXPIRE DEFAULT ACCOUNT UNLOCK;" >> $OUTPUT_FILE
        else
            echo "CREATE USER IF NOT EXISTS '${user}'@'${host}' IDENTIFIED BY 'P@ssw0rd!';" >> $OUTPUT_FILE
        fi
        echo "" >> $OUTPUT_FILE
    fi

    # Handle privilege grants
    if [ "$MODE" == "grant_privileges" ]; then
        # Fetch and append GRANT statements
        GRANTS_QUERY="SHOW GRANTS FOR '${user}'@'${host}';"
        echo "-- Grants for '${user}'@'${host}'" >> $OUTPUT_FILE
        mysql -h$MYSQL_HOST -P$MYSQL_PORT -u$MYSQL_USER --silent --skip-column-names -e "$GRANTS_QUERY" | while read -r grant; do
            echo "${grant};" >> $OUTPUT_FILE
        done
        echo "" >> $OUTPUT_FILE
    fi

    # Handle privilege revocations in revoke mode
    if [ "$MODE" == "revoke" ]; then
        echo "-- Revoke forbidden privileges for '${user}'@'${host}'" >> $OUTPUT_FILE
        echo "REVOKE SUPER, SHUTDOWN, FILE, CREATE TABLESPACE, GRANT OPTION, APPLICATION_PASSWORD_ADMIN,AUDIT_ABORT_EXEMPT,AUDIT_ADMIN,AUTHENTICATION_POLICY_ADMIN,BACKUP_ADMIN,BINLOG_ADMIN,BINLOG_ENCRYPTION_ADMIN,CLONE_ADMIN,CONNECTION_ADMIN,ENCRYPTION_KEY_ADMIN,FLUSH_OPTIMIZER_COSTS,FLUSH_STATUS,FLUSH_TABLES,FLUSH_USER_RESOURCES,GROUP_REPLICATION_ADMIN,GROUP_REPLICATION_STREAM,INNODB_REDO_LOG_ARCHIVE,INNODB_REDO_LOG_ENABLE,PASSWORDLESS_USER_ADMIN,PERSIST_RO_VARIABLES_ADMIN,REPLICATION_APPLIER,REPLICATION_SLAVE_ADMIN,RESOURCE_GROUP_ADMIN,RESOURCE_GROUP_USER,ROLE_ADMIN,SENSITIVE_VARIABLES_OBSERVER,SERVICE_CONNECTION_ADMIN,SESSION_VARIABLES_ADMIN,SET_USER_ID,SHOW_ROUTINE,SYSTEM_USER,SYSTEM_VARIABLES_ADMIN,TABLE_ENCRYPTION_ADMIN,XA_RECOVER_ADMIN ON *.* FROM '${user}'@'${host}';" >> $OUTPUT_FILE
        echo "REVOKE ALL PRIVILEGES ON mysql.proc FROM '${user}'@'${host}';" >> $OUTPUT_FILE
        echo "" >> $OUTPUT_FILE
    fi
done

echo "FLUSH PRIVILEGES;" >> $OUTPUT_FILE

# Replace double backslashes with underscores in database names
sed -i '' 's/\\\\_/_/g' $OUTPUT_FILE
sed -i '' 's/\\_/_/g' $OUTPUT_FILE

# Unset the MYSQL_PWD variable for security
unset MYSQL_PWD

echo "Output generated in $OUTPUT_FILE"
