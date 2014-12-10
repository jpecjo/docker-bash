#!/bin/bash
set -e

# Set variables
DOCKER_API_PORT=4243
TEMPLATE_PATH="/datastore/template"
NGINX_TEMPLATE="nginx_template.conf"
NGINX_VHOSTS_PATH="/datastore/nginx_vhosts"

IMAGE_FILTER=$(echo $RD_OPTION_IMAGE_NAME | cut -d ":" -f 1)

DOCKER_SERVER_SUCCESS=$(nc -z "$RD_OPTION_DOCKER_SERVER" $DOCKER_API_PORT |  grep -oE 'succeeded')

DOCKER_IMAGE=$(curl -s -S -H "Connection-Type application/json" http://"$RD_OPTION_DOCKER_SERVER":"$DOCKER_API_PORT"/images/json?filter="$IMAGE_FILTER" | grep -oE "$RD_OPTION_IMAGE_NAME")


# Function to create a container
function create_docker_container() {
	echo "Creating container..."

	# Create container using remote API
	CONTAINER_ID=$(curl -s -S -X POST -H "Content-Type: application/json" http://"$RD_OPTION_DOCKER_SERVER":4243/containers/create?name="$RD_OPTION_CONTAINER_NAME" -d '{
	"Hostname":"",
	"User":"",
	"Memory":0,
	"MemorySwap":0,
	"AttachStdin":false,
	"AttachStdout":true,
	"AttachStderr":true,
	"PortSpecs":null,
	"Privileged":false,
	"Tty":false,
	"OpenStdin":false,
	"StdinOnce":false,
	"Env":null,
	"Dns":null,
	"Image":"'$RD_OPTION_IMAGE_NAME'",
	"Volumes":{},
	"VolumesFrom":"",
	"WorkingDir":"",
	"ExposedPorts" : { "8080/tcp": 	{} }
	}' | awk -F '"' '{ print $4 }')

	echo "Container $RD_OPTION_CONTAINER_NAME has been created."

	sleep 1
}

# Function to Start a Docker container
function start_container() {
	echo "Starting container $RD_OPTION_CONTAINER_NAME..."
	# Start container
	curl -s -S -X POST -H "Content-Type: application/json" http://"$RD_OPTION_DOCKER_SERVER":"$DOCKER_API_PORT"/containers/"$RD_OPTION_CONTAINER_NAME"/start -d '{
		"PublishAllPorts":true
	}'

	echo "Container $RD_OPTION_CONTAINER_NAME is now running."

	sleep 1
}

# Function to Stop a Docker container
function stop_container() {
	echo "Stopping container $RD_OPTION_CONTAINER_NAME..."
	# Stop container
	curl -s -S -X POST -H "Content-Type: application/json" http://"$RD_OPTION_DOCKER_SERVER":"$DOCKER_API_PORT"/containers/"$RD_OPTION_CONTAINER_NAME"/stop?t=3 

	echo "Container $RD_OPTION_CONTAINER_NAME has been stopped."

	sleep 1
}

# Function to Restart a Docker container
function restart_container() {	
	echo "Restarting container $RD_OPTION_CONTAINER_NAME..."
	# Restart container
	curl -s -S -X POST -H "Content-Type: application/json" http://"$RD_OPTION_DOCKER_SERVER":"$DOCKER_API_PORT"/containers/"$RD_OPTION_CONTAINER_NAME"/restart?t=3

	echo "Container $RD_OPTION_CONTAINER_NAME has been restarted."
}

# Function to Kill a Docker container
function kill_container() {
	echo "Killing container $RD_OPTION_CONTAINER_NAME..."

	# Kill container
	curl -s -S -X POST -H "Content-Type application/json" http://"$RD_OPTION_DOCKER_SERVER":"$DOCKER_API_PORT"/containers/"$RD_OPTION_CONTAINER_NAME"/kill

	echo "Container $RD_OPTION_CONTAINER_NAME is now dead."

	sleep 1 
}

# Function to Delete a Docker container
function delete_container() {
	echo "Deleting container $RD_OPTION_CONTAINER_NAME..."
	echo "Warning, this is unreversible!"
	sleep 3

	# Delete container
	curl -s -S -X DELETE -H "Content-Type application/json" http://"$RD_OPTION_DOCKER_SERVER":"$DOCKER_API_PORT"/containers/"$RD_OPTION_CONTAINER_NAME"

	echo "Container $RD_OPTION_CONTAINER_NAME deleted."
	sleep 1
}

# Function to Get the Docker container port
function get_container_port() {
	echo "Getting mapped container port..."

	if [ -z $CONTAINER_ID ]; then
		PORT=$(curl -s -S -X GET http://$RD_OPTION_DOCKER_SERVER:$DOCKER_API_PORT/containers/$RD_OPTION_CONTAINER_NAME/json | grep -oE '"[1-9]{5}"' | sed 's/^"\(.*\)"$/\1/')
	else
		PORT=$(curl -s -S -X GET http://$RD_OPTION_DOCKER_SERVER:$DOCKER_API_PORT/containers/$CONTAINER_ID/json | grep -oE '"[1-9]{5}"' | sed 's/^"\(.*\)"$/\1/')
	fi

	sleep 2
	
	echo "Got it."
}

# Function to Generate the Nginx Virtual Host config
function generate_nginx_conf() {
	echo "Creating Nginx config..."
	cp "$TEMPLATE_PATH"/"$NGINX_TEMPLATE" "$NGINX_VHOSTS_PATH"/"$RD_OPTION_CONTAINER_NAME".conf
	echo "Done copying template.."
	sed -i "s/DOCKER_SERVER/$RD_OPTION_DOCKER_SERVER/g" /datastore/nginx_vhosts/"$RD_OPTION_CONTAINER_NAME".conf;
	echo "Done adding server IP"
	sed -i "s/CONTAINER_NAME/$RD_OPTION_CONTAINER_NAME/g" /datastore/nginx_vhosts/"$RD_OPTION_CONTAINER_NAME".conf;
	echo "Done creating server name"
	sed -i "s/CONTAINER_PORT/$PORT/g" /datastore/nginx_vhosts/"$RD_OPTION_CONTAINER_NAME".conf;
	echo "Done adding backend port"

	sleep 1
	echo "Done Nginx config."	
	
	sleep 1
	echo "Congratulations! Container is now accessible at http://$RD_OPTION_CONTAINER_NAME.sbx.dc1.toroserver.com"
}

case $1 in

	deploy)
		if [ "$DOCKER_SERVER_SUCCESS" = "succeeded" ]; then
			if [ "$RD_OPTION_IMAGE_NAME" = "$DOCKER_IMAGE" ]; then
				create_docker_container
				start_container
				get_container_port
				generate_nginx_conf
			else
				echo "Image does not exists. Exiting..."
				exit 1
			fi
		else
			echo "Docker server does not exists or is unreachable. Exiting..."
			exit 1
		fi

	;;

	start)
		if [ -f "$NGINX_VHOSTS_PATH"/"$RD_OPTION_CONTAINER_NAME".conf ]; then
			rm -f "$NGINX_VHOSTS_PATH"/"$RD_OPTION_CONTAINER_NAME".conf
		fi

		start_container
		get_container_port
		generate_nginx_conf
		
	;;

	stop)
		
		stop_container

		if [ -f "$NGINX_VHOSTS_PATH"/"$RD_OPTION_CONTAINER_NAME".conf ]; then
			rm -f "$NGINX_VHOSTS_PATH"/"$RD_OPTION_CONTAINER_NAME".conf
		fi
	;;

	restart)
		restart_container

		if [ -f "$NGINX_VHOSTS_PATH"/"$RD_OPTION_CONTAINER_NAME".conf ]; then
			rm -f "$NGINX_VHOSTS_PATH"/"$RD_OPTION_CONTAINER_NAME".conf
		fi
		
		get_container_port
		generate_nginx_conf
	;;

	kill)
		kill_container

		if [ -f "$NGINX_VHOSTS_PATH"/"$RD_OPTION_CONTAINER_NAME".conf ]; then
			rm -f "$NGINX_VHOSTS_PATH"/"$RD_OPTION_CONTAINER_NAME".conf
		fi

	;;

	delete)
		delete_container

		if [ -f "$NGINX_VHOSTS_PATH"/"$RD_OPTION_CONTAINER_NAME".conf ]; then
			rm -f "$NGINX_VHOSTS_PATH"/"$RD_OPTION_CONTAINER_NAME".conf
		fi
	;;

	*)
		echo "Usage: docker_deployer [ deploy | start | stop | restart | kill | delete ]"
		exit 1

esac