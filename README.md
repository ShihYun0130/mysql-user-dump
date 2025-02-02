# mysql-user-dump
A shell script to dump user accounts, revoke RDS forbidden privileges, or dump user privileges

### Usage
#### Create file using vim
```
vim dump_db_user.sh
```
#### Change file permission
```
chmod +x dump_db_user.sh
```
#### Dump users from a database
The output file can be imported to the targert database and migrate user accounts with their original passwords
```
sh dump_db_user.sh ${source_admin_user} ${source_db_host} ${source_db_port} create_users
```
#### Revoke AWS RDS forbidden user privileges
```
sh dump_db_user.sh ${source_admin_user} ${source_db_host} ${source_db_port} revoke
```
#### Dump user privileges from a database
The output file can be imported to the targert database and migrate user privileges
```
sh dump_db_user.sh ${source_admin_user} ${source_db_host} ${source_db_port} grant_privileges
```

