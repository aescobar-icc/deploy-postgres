#!/bin/bash
docker_exec_root() {
	container_name=$1
	script=$2
	docker exec -it -u 0 $container_name sh -c "$script"
}

docker-compose up -d --remove-orphans
sleep 5

docker_exec_root "db-adminer" "echo \"upload_max_filesize = $MAX_FILESIZE\" >> /usr/local/etc/php/conf.d/upload_large_dumps.ini"
docker_exec_root "db-adminer" "echo \"post_max_size = $MAX_FILESIZE\"       >> /usr/local/etc/php/conf.d/upload_large_dumps.ini"
docker_exec_root "db-adminer" "echo \"memory_limit = -1\"           >> /usr/local/etc/php/conf.d/upload_large_dumps.ini"
docker_exec_root "db-adminer" "echo \"max_execution_time = 0\"      >> /usr/local/etc/php/conf.d/upload_large_dumps.ini"