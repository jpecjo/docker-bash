#!/bin/bash
#
DOCKER_API_PORT=4243
NGINX_VHOSTS="/datastore/nginx_vhosts"
NGINX_TEMPLATE="nginx_template.conf"

IMAGE_FILTER=$(echo $RD_OPTION_IMAGE_NAME | cut -d ":" -f 1)

DOCKER_SERVER_SUCCESS=$(nc -z "$RD_OPTION_DOCKER_SERVER" $DOCKER_API_PORT |  grep -oE 'succeeded')
DOCKER_IMAGE=$(curl -H "Connection-Type application/json" http://"$RD_OPTION_DOCKER_SERVER":"$DOCKER_API_PORT"/images/json?filter="$IMAGE_FILTER" | grep -oE "[a-z]+[-][a-z]+[:][a-z]+")

# Test Docker Server if alive
if [ "$DOCKER_SERVER_SUCCESS" = "succeeded" ] && [ "$RD_OPTION_IMAGE_NAME" = "$DOCKER_IMAGE" ]; then 
	echo "Docker server and image exist, proceeding...";  
	
	# Continue creating the Docker container
	# Create container using remote API
	CONTAINER_ID=$(curl -X POST -H "Content-Type: application/json" http://"$RD_OPTION_DOCKER_SERVER":4243/containers/create?name="$RD_OPTION_CONTAINER_NAME" -d '{
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

	# Start container
	curl -X POST -H "Content-Type: application/json" http://"$RD_OPTION_DOCKER_SERVER":"$DOCKER_API_PORT"/containers/"$CONTAINER_ID"/start -d '{
		"PublishAllPorts":true
	}'

	echo "Container $RD_OPTION_CONTAINER_NAME is now running."

	# ## Generate Nginx conf
	echo "Generating Nginx config file..."
	# # NAME=$(curl -X GET http://docker.sandbox.toro:4243/containers/$CONTAINER_ID/json | grep -oE '"Name":"/[aA0-zZ9]{1,10}"' | cut -d ':' -f 2 | sed 's/^"\(.*\)"$/\1/' | cut -c 2-)
	
	# Get container published port(s)
	PORT=$(curl -X GET http://$RD_OPTION_DOCKER_SERVER:$DOCKER_API_PORT/containers/$CONTAINER_ID/json | grep -oE '"[1-9]{5}"' | sed 's/^"\(.*\)"$/\1/')

	# # Replace variables inside Nginx template
	# # Required parameters
	# # 	- CONTAINER_NAME
	# #		- DOCKER_SERVER
	# #		- PORT

	# # Generate Nginx conf
	cp /datastore/nginx_template.conf /datastore/nginx_vhosts/"$RD_OPTION_CONTAINER_NAME".conf
	sed -i "s/DOCKER_SERVER/$RD_OPTION_DOCKER_SERVER/g" /datastore/nginx_vhosts/"$RD_OPTION_CONTAINER_NAME".conf
	sed -i "s/CONTAINER_NAME/$RD_OPTION_CONTAINER_NAME/g" /datastore/nginx_vhosts/"$RD_OPTION_CONTAINER_NAME".conf
	sed -i "s/CONTAINER_PORT/$PORT/g" /datastore/nginx_vhosts/"$RD_OPTION_CONTAINER_NAME".conf

	echo "Done Nginx config." 
	echo "Congratulations! Container is now accessible at http://$RD_OPTION_CONTAINER_NAME.sbx.dc1.toroserver.com"
	exit 0

	# If image does not exist, exit script
	echo "Image does not exist. Exiting..."; 
	exit 1

else 
	# If Docker server is inaccessible, exit script
	echo "Docker server inaccessible, exiting..."; 
	exit 1
fi

exit 0