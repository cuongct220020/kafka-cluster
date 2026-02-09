#!/bin/bash
IMAGE_VERSION=${1:-7.7.7}
IMAGE="confluentinc/cp-kafka:$IMAGE_VERSION"

CLUSTER_ID=$(docker run --rm "$IMAGE" kafka-storage random-uuid 2>/dev/null)

if [ $? -eq 0 ] && [ -n "$CLUSTER_ID" ]; then
    echo "Success! Copy the ID below:"
    echo "$CLUSTER_ID"
else
    echo "Error: Failed to generate Cluster ID."
    echo "Make sure Docker is running and you have internet access to pull the image if needed."
    exit 1
fi