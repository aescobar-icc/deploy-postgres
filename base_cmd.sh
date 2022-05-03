#!/bin/bash

# author: Adán Escobar
# mail: adan@codeits.cl
# linkedin: https://www.linkedin.com/in/aescobar-ing-civil-computacion/


DIR_BASE=$(pwd)

repo_resolve(){
	url=$1
	re="^(https|git)(:\/\/|@)([^\/:]+)[\/:]([^\/:]+)\/(.+)(.git)*$"

	if [[ -z $url ]]; then
		if [ "${gitlabSourceRepoSshUrl+defined}" = defined ]; then
			url="$gitlabSourceRepoSshUrl"
			PROJECT_GIT_BRANCH=$gitlabBranch
		else
			echo "[repo_resolve] Error: url is empty"
			return 1
		fi
	fi

	if [[ $url =~ $re ]]; then    
		#protocol=${BASH_REMATCH[1]}
		#separator=${BASH_REMATCH[2]}
		PROJECT_GIT_HOST=${BASH_REMATCH[3]}
		PROJECT_GIT_WORKSPACE=${BASH_REMATCH[4]}
		reponame=${BASH_REMATCH[5]}
		PROJECT_NAME=${reponame%.*}
	fi

	if [ "$PROJECT_GIT_HOST" = "gitlab.bermann.cl" ]; then
		PROJECT_GIT_HOST="192.168.101.178"
	fi

	if [[ -z $PROJECT_GIT_BRANCH ]]; then
		PROJECT_GIT_BRANCH="master"
	fi
	

	echo "[repo_resolve] PROJECT_GIT_HOST: $PROJECT_GIT_HOST"
	echo "[repo_resolve] PROJECT_GIT_WORKSPACE: $PROJECT_GIT_WORKSPACE"
	echo "[repo_resolve] PROJECT_NAME: $PROJECT_NAME"
	echo "[repo_resolve] PROJECT_GIT_BRANCH: $PROJECT_GIT_BRANCH"
}
repo_clone(){
	PROJECT_NAME=$1
	PROJECT_TYPE="docker"
	PROJECT_GIT_BRANCH="master"
	PROJECT_GIT_HOST="bitbucket.org"
	PROJECT_GIT_WORKSPACE="bermann-cloud"
	PROJECT_GIT_RESET_HARD=false
	SSH_KEY="/var/jenkins_home/.ssh/git_bermann_key"

	PARSE_URL=false

	#read config arguments
	for args in "$@"
	do
		key=$(echo $args | cut -f1 -d=)
		value=$(echo $args | cut -f2 -d=)   

		case "$key" in
			name)        PROJECT_NAME=${value} ;;
			branch)      PROJECT_GIT_BRANCH=${value} ;;
			"git-host")        PROJECT_GIT_HOST=${value} ;;
			"git-ws")          PROJECT_GIT_WORKSPACE=${value} ;;
			"--git-url") PROJECT_GIT_URL=${value}  PARSE_URL=true ;;
			"--git-reset-hard")  PROJECT_GIT_RESET_HARD=true ;;
			"--proj-type")     PROJECT_TYPE=${value} ;;
				*)   
		esac
	done

	if [[ "$1" = git@* ]]; then
		repo_resolve $1
	elif [[ "$PROJECT_GIT_URL" = git@* ]]; then
		repo_resolve $PROJECT_GIT_URL
	fi

	PROJECT_GIT_URL=git@$PROJECT_GIT_HOST:$PROJECT_GIT_WORKSPACE/$PROJECT_NAME.git

	echo "[repo_clone] ----------------------------- $PROJECT_NAME [$PROJECT_GIT_BRANCH] -----------------------------------"

	# eval `ssh-agent -s`
	# ssh-add -k ${SSH_KEY}

	if [ ! -d $DIR_BASE/$PROJECT_NAME ]; then
		cd $DIR_BASE
		echo "[repo_clone] clonning $PROJECT_GIT_URL"
		git clone -b $PROJECT_GIT_BRANCH $PROJECT_GIT_URL
	else
		cd $DIR_BASE/$PROJECT_NAME
		echo "[repo_clone] updating $PROJECT_NAME:$PROJECT_GIT_BRANCH"
		git config pull.rebase false
		if [ "$PROJECT_GIT_RESET_HARD" = true ]; then
			git reset --hard
		fi
		
		git checkout $PROJECT_GIT_BRANCH
		git pull origin $PROJECT_GIT_BRANCH
	fi
	cd $DIR_BASE
}
repo_build(){
	repo_clone $@
	if [ "$PROJECT_TYPE" == "docker" ]; then
		cd $DIR_BASE/$PROJECT_NAME
		echo "[repo_build] building docker image"
		source ./dockerbuild.sh
	elif [ "$PROJECT_TYPE" == "jar-app" ]; then
		cd $DIR_BASE/$PROJECT_NAME
		bash jar-make.sh $@
	fi
	cd $DIR_BASE
}
# nexus_get_latest(){
# 	$APP_NAME=jbParser
# 	$APP_BRACH=set-commons
# 	NEXUS_SERVER="http://10.10.2.147:8081"
# 	NEXUS_REPO_JAVA_APPS="bermann-java-apps"
# 	NEXUS_GROUP="/$APP_NAME/$APP_BRACH"
# 	curl "$NEXUS_SERVER/service/rest/v1/search/assets/download?sort=version&repository=$NEXUS_REPO_JAVA_APPS&group=$NEXUS_GROUP" -L --output $APP_NAME-$APP_BRACH-latest.zip
# }
# nexus_get_latest_url(){
# curl "http://10.10.2.147:8081/service/rest/v1/search/assets?sort=version&repository=bermann-java-apps&group=/jbParser/set-commons&" | jq '.items[0].downloadUrl'
# }
remote_terminal(){
	usrhost=$1
	script=$2
	echo "[remote_terminal] -------------------------------------------------------------------------------------------------"
	echo "[remote_terminal] 🖥️  $usrhost\$ $script"
	echo "[remote_terminal] -------------------------------------------------------------------------------------------------"
	ssh -T $usrhost "$script"
}
download_artifact_on_remote(){
	# echo "[download_artifact_on_remote] 📦 -----------------  start -------------------"
	# echo "[download_artifact_on_remote] 📦 $@"
	userhost=$1
	NEXUS_ARTIFACT_URL=$2
	APP_NAME=$3

	APP_PATH=$REMOTE_HOST_JAVA_APPS_PATH/$APP_NAME
	ARTIFACT_NAME=$(echo $NEXUS_ARTIFACT_URL | sed -e 's/.*\///g')
	ARTIFACT_PATH=$REMOTE_HOST_JAVA_APPS_PATH/$ARTIFACT_NAME
	#userhost="$REMOTE_HOST_DEPLOYER_USER@$REMOTE_HOST"

	#echo "---- connecting remote server: $userhost to apply "
	echo "[download_artifact_on_remote] 📦 checking remote path: $APP_PATH"
	remote_terminal $userhost "sudo mkdir -p $APP_PATH && sudo chown -R $REMOTE_HOST_DEPLOYER_USER $REMOTE_HOST_JAVA_APPS_PATH"
	
	echo "[download_artifact_on_remote] 📦 downloading from nexus:$NEXUS_ARTIFACT_URL"
	remote_terminal $userhost "cd $REMOTE_HOST_JAVA_APPS_PATH && curl -O $NEXUS_ARTIFACT_URL" 

	echo "[download_artifact_on_remote] 📦 unpacking artifact $ARTIFACT_NAME"
    remote_terminal $userhost "rm -rf $APP_PATH/* && unzip  -o $ARTIFACT_PATH -d $APP_PATH && cd $APP_PATH && pwd && ls -ltr"
	echo "[download_artifact_on_remote] 🍻 done"
}
# jar_deploy(){
# 	echo "[jar_deploy] $@"
# 	INSTANCE_INDEX=$1
# 	REMOTE_HOST=$2
# 	NEXUS_ARTIFACT_URL=$3
# 	APP_NAME=$4
# 	APP_ARGS=("${@:5}")
# 	APP_PATH=$REMOTE_HOST_JAVA_APPS_PATH/$APP_NAME
# 	ARTIFACT_NAME=$(echo $NEXUS_ARTIFACT_URL | sed -e 's/.*\///g')
# 	ARTIFACT_PATH=$REMOTE_HOST_JAVA_APPS_PATH/$ARTIFACT_NAME
# 	userhost="$REMOTE_HOST_DEPLOYER_USER@$REMOTE_HOST"
# 	echo "---- connecting remote server: $userhost to apply "
# 	echo "---- checking remote path: $REMOTE_HOST_JAVA_APPS_PATH"
# 	remote_terminal $userhost "sudo mkdir -p $REMOTE_HOST_JAVA_APPS_PATH && sudo chown -R $REMOTE_HOST_DEPLOYER_USER $REMOTE_HOST_JAVA_APPS_PATH"
	
# 	echo "---- downloading from nexus:$NEXUS_ARTIFACT_URL"
# 	remote_terminal $userhost "cd $REMOTE_HOST_JAVA_APPS_PATH && curl -O $NEXUS_ARTIFACT_URL" 

# 	echo "---- unpacking and install artifact $ARTIFACT_NAME"
# 	s="rm -rf $APP_PATH/* && unzip  -o $ARTIFACT_PATH -d $APP_PATH && cd $APP_PATH && pm2 start jar-run.sh --instances=1 --time  --name=\"$APP_NAME-$INSTANCE_INDEX ${APP_ARGS[@]}\" -- ${APP_ARGS[@]}"
# 	echo "script: $s"
#     remote_terminal $userhost "$s"
# 	echo "----------------- done -------------------"
# }


#usage: jar_deploy_env test $repo $repo_namespace $app_name $app_branch $app_artifact
# re-deploy only app pushed if is given
# if none app is given, re-deploy all with first branch
jar_deploy_env(){
	DEPLOY_ENV=$1 #dev, qa, prod
	YAML="deploy-$DEPLOY_ENV.yaml"

	if [[ ! -f "$YAML" ]]; then
		echo "[jar_deploy_env] 🚫 $YAML does not exists in path: $(pwd)."
		return 1
	fi
	
	# if app name is not given, deploy all
	if [[ -z "$2" || "$2" == "*" ]]; then
		SET_APP=false
	else
		SET_APP=true
		APP_NAME=$2
		APP_BRANCH=$3
		APP_ARTIFACT=$4
	fi
	
	#get deploy file from repository
	# echo "[jar_deploy_env] Getting deploy file:$YAML from repository"
	# git archive --remote=ssh://$DEPLOY_REPO HEAD $DEPLOY_REPO_GROUP_JAVA_APP/$YAML | tar -xO > $YAML
	echo "[jar_deploy_env] -------------------------------------------------------------------------------------------------"
	echo "[jar_deploy_env] 🚀 DEPLOYING : $YAML"
	echo "[jar_deploy_env] -------------------------------------------------------------------------------------------------"

	apps=$(yq ".apps[] | key" $YAML)
	if [ ${#apps[@]} -eq 0 ]; then
		echo "[jar_deploy_env] 🚫  ERROR: $YAML does not define apps."
		return 1
	fi
	for app in $apps; do
		# if app is given, only deploy this app
		if [[ "$SET_APP" = true && "$app" != "$APP_NAME" ]]; then
			echo "[jar_deploy_env] ⏭️ skipping app: $app ≠ $APP_NAME"
			continue
		fi

		echo "[jar_deploy_env] -------------------------------------------------------------------------------------------------"
		echo "[jar_deploy_env] 🚀  Processing app: $app from YAML [.apps.$app]"
		echo "[jar_deploy_env] -------------------------------------------------------------------------------------------------"

		define_env_file=$(yq ".apps.$app | has(\"env_file\")" $YAML)
		if [[ "$define_env_file" = true ]]; then
			ENV_FILE=$(yq ".apps.$app.env_file" $YAML)
			echo "[jar_deploy_env] 📦 Getting env_file: $ENV_FILE from YAML [.apps.$app.env_file]"
			ENV_FILE="--use-env=$ENV_FILE"
		else
			ENV_FILE="--use-env=.env"
			echo "[jar_deploy_env] 📦 Using default env_file: $ENV_FILE from YAML [.apps.$app.env_file]"
		fi

		#echo "[jar_deploy_env] resolve artifact"
		# resolve artifact that must be deployed
		define_artifact=$(yq ".apps.$app | has(\"artifact\")" $YAML)
		# if yaml define artifact, use it
		if [ "$define_artifact" == true ]; then
			artifact_url=$(yq ".apps.$app.artifact" $YAML )
			echo "[jar_deploy_env] 📦  using artifact: $artifact_url from yaml [.apps.$app.artifact]"
		else
		#resolve artifact
			branch_parametized=$(yq ".apps.$app.branch | has(\"parametized\")" $YAML)
			if [[ "$branch_parametized" == true ]]; then
				branch_parametized=$(yq ".apps.$app.branch.parametized" $YAML)
			fi
			# if app yaml config define branch.parametized=true, use parameters values
			if [[ "$SET_APP" = true && "$branch_parametized" == true ]]; then
				group="$APP_NAME/$APP_BRANCH"
				artifact_url="$NEXUS_SERVER/repository/$NEXUS_REPO_JAVA_APPS/$group/$APP_ARTIFACT"
				echo "[jar_deploy_env] 📦 Using artifact: $artifact_url from pipeline parameters"
			else
				branch=$(yq ".apps.$app.branch.default" $YAML )
				echo "[jar_deploy_env] 📦 Using default branch:$branch  from yaml [.apps.$app.branch.default]"
				group="/$app/$branch"
				#get last version
				nexus_url="$NEXUS_SERVER/service/rest/v1/search/assets?sort=version&repository=$NEXUS_REPO_JAVA_APPS&group=$group"
				echo "[jar_deploy_env] 📦 Resolving latest artifact version from nexus in : $nexus_url"
				artifact_url=$(curl -s $nexus_url | jq '.items[-1].downloadUrl' --raw-output)
				echo "[jar_deploy_env] 📦  using artifact: $artifact_url latest from nexus"
			fi
		fi
		if [[ -z "$artifact_url" ||  "$artifact_url" == null ]]; then
			echo "[jar_deploy_env] 🚫  ERROR: artifact_url: '$artifact_url' is invalid!. IMPORTANT: check that app name and branch are correct and exists on nexus!!."
			return 1
		fi
		#echo "[jar_deploy_env] artifact_url: $artifact_url"

		hosts=$(yq ".apps.$app.hosts[] | key" $YAML )
		if [ ${#hosts[@]} -eq 0 ]; then
			echo "[jar_deploy_env] 🚫  ERROR:$YAML does not define [.$app.hosts]"
			return 1
		fi
		#echo "[jar_deploy_env] hosts: $hosts"
		# iterate each host that app must be deployed
		for h in $hosts; do
			#echo "	host index:$h"
			host=$(yq ".apps.$app.hosts[$h].host" $YAML )
			#echo "[jar_deploy_env]	🖥️  host:$host"

			userhost="$REMOTE_HOST_DEPLOYER_USER@$host"
			echo "[jar_deploy_env] 🧨 ---- kill previus versions of $app on $userhost"
			#ssh -tT $REMOTE_HOST_DEPLOYER_USER@$host "ps -fe | grep $app && ps -fe | grep $app | awk '{print \$2;}' | xargs kill -9 > /dev/null"
			#ssh -tT $REMOTE_HOST_DEPLOYER_USER@$host "pm2 list | grep $app | awk '{print \$2}' | xargs pm2 delete"
			remote_terminal $userhost "pm2 list | grep $app | awk '{print \$2}' | xargs pm2 delete"
			
			echo "[jar_deploy_env] 📦 ---- downloadig artifact of $app on $userhost"
			download_artifact_on_remote $userhost "$artifact_url" $app 
			# iterate each instance that must be deployed by host
			instances=$(yq ".apps.$app.hosts[$h].instances[] | key" $YAML )
			if [ ${#instances[@]} -eq 0 ]; then
				echo "[jar_deploy_env] 🚫  ERROR:$YAML does not instances [.$app.instances]"
				return 1
			fi
			for i in $instances; do
				args=($(yq ".apps.$app.hosts[$h].instances[$i].args[]" $YAML ))
				echo "[jar_deploy_env] 🚀  DEPLOYING  host:$host  INSTANCE:$app-$i args:${args[@]}"

				#jar_deploy $i $host "$artifact_url" $app ${args[@]} $ENV_FILE
				args=$(echo "${args[@]}")
				app_path=$REMOTE_HOST_JAVA_APPS_PATH/$app
				#remote_terminal $userhost "cd $app_path && pm2 start jar-run.sh --no-autorestart --time  --name=\"$app-$i $args\" -- $args"
				remote_terminal $userhost "cd $app_path && bash jar-run.sh --instance-id=$i $args"
			done
		done
	done
}
