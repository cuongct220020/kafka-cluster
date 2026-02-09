#!/bin/bash

# Default values
BOOTSTRAP_SERVER="kafka-1:9092"
PARTITIONS=3
REPLICATION_FACTOR=3
TOPIC=""
ACTION=""

# Colors for output
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Function to display usage
usage() {
  echo -e "${BLUE}Kafka Topic Manager${NC}"
  echo "Usage: $0 -a <action> [options]"
  echo ""
  echo "Actions (-a):"
  echo "  create    Create a new topic"
  echo "  delete    Delete an existing topic"
  echo "  describe  Describe a topic"
  echo "  list      List all topics"
  echo ""
  echo "Options:"
  echo "  -t <topic>        Topic name (Required for create, delete, describe)"
  echo "  -p <partitions>   Number of partitions (Default: 3, create only)"
  echo "  -r <replication>  Replication factor (Default: 3, create only)"
  echo "  -b <broker>       Bootstrap server (Default: kafka-1:9092)"
  echo "  -h                Show this help message"
  echo ""
  echo "Examples:"
  echo "  $0 -a create -t my-topic"
  echo "  $0 -a create -t my-topic -p 5 -r 2"
  echo "  $0 -a describe -t my-topic"
  echo "  $0 -a list"
  exit 1
}

# Parse arguments
while getopts "a:t:p:r:b:h" opt; do
  case $opt in
    a) ACTION=$OPTARG ;;
    t) TOPIC=$OPTARG ;;
    p) PARTITIONS=$OPTARG ;;
    r) REPLICATION_FACTOR=$OPTARG ;;
    b) BOOTSTRAP_SERVER=$OPTARG ;;
    h) usage ;;
    *) usage ;;
  esac
done

# Validate action
if [[ -z "$ACTION" ]]; then
  echo -e "${RED} Error: Action (-a) is required.${NC}"
  usage
fi

# Function to run docker command
run_kafka_cmd() {
  docker exec kafka-1 /opt/kafka/bin/kafka-topics.sh --bootstrap-server "$BOOTSTRAP_SERVER" "$@"
}

# Execute based on action
case $ACTION in
  create)
    if [[ -z "$TOPIC" ]]; then
      echo -e "${RED} Error: Topic name (-t) is required for creation.${NC}"
      exit 1
    fi
    echo -e "${GREEN} Creating topic: $TOPIC (Partitions: $PARTITIONS, Replication: $REPLICATION_FACTOR)...${NC}"
    run_kafka_cmd --create --topic "$TOPIC" --partitions "$PARTITIONS" --replication-factor "$REPLICATION_FACTOR" \
      || echo -e "${YELLOW} Topic may already exist or error occurred.${NC}"
    ;;
  
  delete)
    if [[ -z "$TOPIC" ]]; then
      echo -e "${RED} Error: Topic name (-t) is required for deletion.${NC}"
      exit 1
    fi
    echo -e "${YELLOW} Deleting topic: $TOPIC...${NC}"
    run_kafka_cmd --delete --topic "$TOPIC" \
      || echo -e "${YELLOW}Topic may not exist or deletion pending.${NC}"
    ;;
  
  describe)
    if [[ -z "$TOPIC" ]]; then
      echo -e "${RED} Error: Topic name (-t) is required for description.${NC}"
      exit 1
    fi
    echo -e "${BLUE} Describing topic: $TOPIC...${NC}"
    run_kafka_cmd --describe --topic "$TOPIC"
    ;;
  
  list)
    echo -e "${BLUE} Listing topics...${NC}"
    run_kafka_cmd --list
    ;;
  
  *)
    echo -e "${RED} Error: Invalid action '$ACTION'.${NC}"
    usage
    ;;
esac
