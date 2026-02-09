#!/bin/bash

# Script to generate kafka_server_jaas.conf from environment variables
# Usage: ./generate-jaas.sh

# Load environment variables from .env if exists
if [ -f .env ]; then
    export $(cat .env | grep -v '^#' | xargs)
fi

# Create JAAS configuration file
cat > kafka_server_jaas.conf <<EOF
KafkaServer {
   org.apache.kafka.common.security.scram.ScramLoginModule required
   username="admin"
   password="${KAFKA_ADMIN_PASSWORD}";
};
EOF

echo "kafka_server_jaas.conf has been generated with password from .env"








