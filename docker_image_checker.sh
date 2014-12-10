#!/bin/bash
IMAGE_NAME=toro-c:sandbox
IMAGE_FILTER=$(echo $IMAGE_NAME | cut -d ":" -f 1)

DOCKER_IMAGE=$(curl -H "Connection-Type application/json" http://10.15.100.8:4243/images/json?filter="$IMAGE_FILTER" | grep -oE "[a-z]+[-][a-z]+[:][a-z]+")

if [ "$IMAGE_NAME" = "$DOCKER_IMAGE" ]; then 
	echo "Image match, proceeding..."; 
else 
	echo "Image does not exist. Exiting..."; 
fi


