# Kafka Cluster Setup

B1. Khởi tạo CA
- Tạo CA private key + certificate (self-signed)
```bash
openssl genrsa -out ca/private/ca-key.pem 4096
chmod 600 ca/private/ca-key.pem

openssl req \
  -config openssl-ca.cnf \
  -key ca/private/ca-key.pem \
  -new -x509 \
  -days 3650 \
  -sha256 \
  -extensions ca_extensions \
  -out ca/certs/ca-cert.pem
```
- Khởi tạo CA database (index.txt, serial.txt)
```bash
cd ca
touch index.txt
echo 1000 > serial
echo 1000 > crlnumber

mkdir -p certs new_certs private crl
```

B2. Lặp lại cho từng Broker

- Sinh keypair cho broker (keystore)
```bash
keytool -genkeypair \
  -keystore broker-1.keystore.p12 \
  -alias broker-1 \
  -keyalg RSA \
  -keysize 2048 \
  -storetype PKCS12 \
  -validity 3650 \
  -dname "CN=broker-1" \
  -ext SAN=DNS:broker-1,DNS:localhost,IP:127.0.0.1
```


- Tạo CSR từ keypair đó (có SAN)
```bash
keytool -certreq \
  -keystore broker-1.keystore.p12 \
  -alias broker-1 \
  -file broker-1.csr \
  -ext SAN=DNS:broker-1,DNS:localhost,IP:127.0.0.1
```

- CA ký CSR → broker certificate
```bash
openssl ca \
  -config openssl-ca.cnf \
  -policy signing_policy \
  -extensions kafka_server_ext \
  -in broker-1.csr \
  -out broker-1-cert.pem \
  -days 3650 \
  -notext \
  -batch
```

- Import CA cert + broker cert vào keystore
```bash
# Import CA cert (chain of trust)
keytool -importcert \
  -keystore broker-1.keystore.p12 \
  -alias CARoot \
  -file certs/ca-cert.pem \
  -storetype PKCS12 \
  -noprompt
```

```bash
# Import broker cert
keytool -importcert \
  -keystore broker-1.keystore.p12 \
  -alias broker-1 \
  -file broker-1-cert.pem \
  -storetype PKCS12
```


B3. Trust
- Import CA cert vào truststore (dùng chung)
```bash
keytool -importcert \
  -keystore kafka.truststore.p12 \
  -alias CARoot \
  -file certs/cacert.pem \
  -storetype PKCS12 \
  -noprompt
```