#!/bin/bash
set -e

if [ -f .env ]; then
  export $(grep -v '^#' .env | xargs)
fi

CA_NAME="${1:-${CA_NAME:-Kafka-Security-CA}}"
STORE_PASS="${2:-${KAFKA_SSL_SECRET:-confluent}}"
COUNTRY_CODE="${3:-${COUNTRY_CODE:-VN}}"

ORG_UNIT="IT-Department"
ORG_NAME="MyCompany"
CITY="Hanoi"
SECRETS_DIR="./secrets"

echo ">>> CONFIG:"
echo "   CA Name: $CA_NAME"
echo "   Country: $COUNTRY_CODE"
echo "   Password: **** (Hidden)"

mkdir -p $SECRETS_DIR
cd $SECRETS_DIR

echo "Create CA Private Key (ca-key.pem)..."
openssl genrsa -out ca-key.pem 2048


echo "Create CA Certificate (ca-cert.pem)..."
openssl req -new -x509 \
    -key ca-key.pem \
    -out ca-cert.pem \
    -days 3650 \
    -subj "/C=$COUNTRY_CODE/ST=$CITY/L=$CITY/O=$ORG_NAME/OU=$ORG_UNIT/CN=$CA_NAME"


echo "Create Common Truststore (kafka.truststore.jks)..."
rm -f kafka.truststore.jks

keytool -keystore kafka.truststore.jks \
    -alias CARoot \
    -import -file ca-cert.pem \
    -storepass "$STORE_PASS" \
    -noprompt


echo "Create Keystore for Brokers..."
# Lưu ý: SAN (Subject Alternative Name) cực kỳ quan trọng để Broker nhận diện nhau qua Docker Network và Localhost
for i in 1 2 3; do
    BROKER="kafka-$i"
    echo "Processing $BROKER..."

    # 1. Create Keystore
    keytool -genkeypair -alias $BROKER -keystore $BROKER.keystore.jks -keyalg RSA -keysize 2048 \
        -validity 3650 -storepass confluent -keypass confluent \
        -dname "CN=$BROKER, OU=IT, O=MyCompany, L=Hanoi, C=VN" \
        -ext "SAN=DNS:$BROKER,DNS:localhost,IP:127.0.0.1"

    # 2. Create CSR
    keytool -certreq -alias $BROKER -keystore $BROKER.keystore.jks -file $BROKER.csr -storepass confluent

    # 3. Sign CSR by CA
    openssl x509 -req -CA ca-cert.pem -CAkey ca-key.pem -in $BROKER.csr -out $BROKER-signed.pem \
        -days 3650 -CAcreateserial -passin pass:confluent \
        -extensions v3_req -extfile <(printf "[v3_req]\nsubjectAltName=DNS:$BROKER,DNS:localhost,IP:127.0.0.1")

    # 4. Import signed CA and Cert to Keystore
    keytool -importcert -alias CARoot -file ca-cert.pem -keystore $BROKER.keystore.jks -storepass confluent -noprompt
    keytool -importcert -alias $BROKER -file $BROKER-signed.pem -keystore $BROKER.keystore.jks -storepass confluent -noprompt

    rm $BROKER.csr $BROKER-signed.pem
done

chmod -R 777 .
echo ">>> DONE! Secrets generated in $SECRETS_DIR"