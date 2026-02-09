#!/bin/bash
set -e

# --- 1. Load biến môi trường an toàn (Fix lỗi dòng mới Windows \r) ---
if [ -f .env ]; then
    export $(grep -v '^#' .env | tr -d '\r' | xargs)
fi

# Image mặc định trùng với file docker-compose
IMAGE=${KAFKA_IMAGE:-confluentinc/cp-kafka:7.7.1}

# --- 2. Xử lý Cluster ID ---
if [ -z "$CLUSTER_ID" ]; then
    echo "🆔 Generating new Cluster ID..."
    CLUSTER_ID=$(docker run --rm "$IMAGE" kafka-storage random-uuid)
    if [ -z "$CLUSTER_ID" ]; then echo "❌ Error: Failed to generate Cluster ID"; exit 1; fi

    echo "" >> .env
    echo "CLUSTER_ID=$CLUSTER_ID" >> .env
    export CLUSTER_ID
    echo "✅ New ID generated: $CLUSTER_ID"
else
    echo "🆔 Using existing Cluster ID: $CLUSTER_ID"
fi

# --- 3. Tạo SSL Certs (Nếu chưa có) ---
if [ ! -f "./secrets/kafka.truststore.jks" ]; then
    echo "🔒 Generating SSL Certificates..."
    if [ -f "scripts/config-security.sh" ]; then
        chmod +x scripts/config-security.sh
        ./scripts/config-security.sh "$CA_NAME" "$KAFKA_SSL_SECRET" "$COUNTRY_CODE"
    else
        echo "⚠️  Warning: scripts/config-security.sh not found. Skipping SSL generation."
    fi
fi

# --- 4. Reset Docker Volumes ---
echo "📦 Resetting Docker Volumes (Clean Slate)..."
docker volume rm -f kafka-1-data kafka-2-data kafka-3-data > /dev/null
docker volume create kafka-1-data > /dev/null
docker volume create kafka-2-data > /dev/null
docker volume create kafka-3-data > /dev/null

# --- 5. Format Storage & Bootstrap (LOGIC CỐT LÕI) ---
echo "🚀 Formatting storage and injecting credentials..."

docker run --rm \
  -v kafka-1-data:/data/kafka-1 \
  -v kafka-2-data:/data/kafka-2 \
  -v kafka-3-data:/data/kafka-3 \
  -e CID="$CLUSTER_ID" \
  -e AP="$KAFKA_ADMIN_PASSWORD" \
  -e CP="$KAFKA_CLIENT_PASSWORD" \
  --entrypoint /bin/bash \
  "$IMAGE" -c '
    set -e

    # === HÀM TẠO CONFIG HỢP LỆ (Fix lỗi Validation) ===
    create_valid_config() {
        NODE_ID=$1
        FILE="/tmp/node$NODE_ID.properties"

        # 1. Định danh Node
        echo "node.id=$NODE_ID" > $FILE
        echo "process.roles=broker,controller" >> $FILE
        echo "controller.quorum.voters=1@localhost:9093" >> $FILE

        # 2. Cấu hình Listeners (QUAN TRỌNG ĐỂ FIX LỖI)
        # Lỗi cũ: Thiếu advertised listener cho vai trò Broker.
        # Fix: Khai báo thêm listener PLAINTEXT giả lập.
        echo "controller.listener.names=CONTROLLER" >> $FILE
        echo "listeners=CONTROLLER://:9093,PLAINTEXT://:9092" >> $FILE
        echo "advertised.listeners=PLAINTEXT://localhost:9092" >> $FILE

        # Map protocol để tool format hiểu (dùng PLAINTEXT cho đơn giản lúc format)
        echo "listener.security.protocol.map=CONTROLLER:PLAINTEXT,PLAINTEXT:PLAINTEXT" >> $FILE

        # 3. Đường dẫn dữ liệu
        echo "log.dirs=/data/kafka-$NODE_ID" >> $FILE
    }

    # --- Node 1: Format KÈM User Admin/Client ---
    create_valid_config 1
    echo "   -> Formatting Node 1 (Bootstrap Node)..."
    kafka-storage format --ignore-formatted -t $CID -c /tmp/node1.properties \
      --add-scram "SCRAM-SHA-256=[name=admin,password=$AP]" \
      --add-scram "SCRAM-SHA-256=[name=client,password=$CP]"

    # --- Node 2: Chỉ Format ---
    create_valid_config 2
    echo "   -> Formatting Node 2..."
    kafka-storage format --ignore-formatted -t $CID -c /tmp/node2.properties

    # --- Node 3: Chỉ Format ---
    create_valid_config 3
    echo "   -> Formatting Node 3..."
    kafka-storage format --ignore-formatted -t $CID -c /tmp/node3.properties

    # --- Fix quyền file ---
    echo "   -> Setting permissions (uid:1000)..."
    chown -R 1000:1000 /data/kafka-1 /data/kafka-2 /data/kafka-3
    chmod -R 700 /data/kafka-1 /data/kafka-2 /data/kafka-3
'

echo "✅ Cluster initialized successfully!"
echo "👉 You can now run: docker compose up -d"