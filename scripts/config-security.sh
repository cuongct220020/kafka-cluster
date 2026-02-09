#!/bin/bash

SECRETS_DIR="./secrets"
mkdir -p $SECRETS_DIR


echo "Create CA (Certificate Authority)..."
openssl genrsa -out ca-key.pem 2048
openssl req -new -x509 -key ca-key.pem -out ca-cert.pem -days 3650 -subj "/CN=Kafka-Security-CA"


# Crete Truststore
keytool -keystore kafka.truststore.jks -alias CARoot -import -file ca-cert.pem -storepass confluent -keypass -noprompt


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