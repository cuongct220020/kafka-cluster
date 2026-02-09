import os
from dotenv import load_dotenv
from confluent_kafka import Producer, Consumer, KafkaError

# Load environment variables from .env file
load_dotenv()

class SecureKafkaClient:
    """
    A template for secure Kafka connection using SASL_SSL and SCRAM-SHA-256.
    Follows best practices:
    1. Credentials via Environment Variables.
    2. Centralized configuration.
    3. Proper error handling.
    """
    
    @staticmethod
    def get_config():
        """
        Builds the configuration dictionary for confluent-kafka.
        """
        conf = {
            'bootstrap.servers': os.getenv('KAFKA_BOOTSTRAP_SERVERS', 'localhost:9092'),
            'security.protocol': os.getenv('KAFKA_SECURITY_PROTOCOL', 'SASL_SSL'),
            'sasl.mechanism': os.getenv('KAFKA_SASL_MECHANISM', 'SCRAM-SHA-256'),
            'sasl.username': os.getenv('KAFKA_SASL_USERNAME'),
            'sasl.password': os.getenv('KAFKA_SASL_PASSWORD'),
            
            # SSL Configuration
            'ssl.ca.location': os.getenv('KAFKA_SSL_CA_LOCATION', '../../secrets/ca-cert.pem'),
            'enable.ssl.certificate.verification': os.getenv('KAFKA_SSL_VERIFY', 'True').lower() == 'true',
        }
        
        # Validate critical config
        if not conf['sasl.username'] or not conf['sasl.password']:
            print("WARNING: SASL credentials not found in environment variables!")
            
        return conf

    @classmethod
    def create_producer(cls):
        """
        Creates a secure Producer instance.
        """
        conf = cls.get_config()
        
        # Best practice: Add delivery report callback
        def delivery_report(err, msg):
            if err is not None:
                print(f"Message delivery failed: {err}")
            else:
                print(f"Message delivered to {msg.topic()} [{msg.partition()}]")

        return Producer(conf)

    @classmethod
    def create_consumer(cls, group_id, topics):
        """
        Creates a secure Consumer instance.
        """
        conf = cls.get_config()
        conf['group.id'] = group_id
        conf['auto.offset.reset'] = 'earliest'
        
        consumer = Consumer(conf)
        consumer.subscribe(topics)
        return consumer

# --- Usage Examples ---

def run_producer_example():
    producer = SecureKafkaClient.create_producer()
    topic = "orders"
    
    try:
        print(f"Producing to topic: {topic}")
        producer.produce(topic, key="key1", value="Hello Secure Kafka", 
                         callback=lambda err, msg: print(f"Sent: {msg.value()}") if err is None else print(err))
        
        # Wait for any outstanding messages to be delivered
        producer.flush()
    except Exception as e:
        print(f"Error in producer: {e}")

def run_consumer_example():
    topic = "orders"
    consumer = SecureKafkaClient.create_consumer(group_id="billing-service", topics=[topic])
    
    print(f"Consuming from topic: {topic}...")
    try:
        while True:
            msg = consumer.poll(1.0)
            if msg is None:
                continue
            if msg.error():
                if msg.error().code() == KafkaError._PARTITION_EOF:
                    continue
                else:
                    print(f"Consumer error: {msg.error()}")
                    break
            
            print(f"Received message: {msg.value().decode('utf-8')}")
    except KeyboardInterrupt:
        pass
    finally:
        consumer.close()

if __name__ == "__main__":
    # Uncomment the one you want to test
    # run_producer_example()
    # run_consumer_example()
    print("Secure Kafka Client Template Loaded.")
    print("Configure your .env file and call run_producer_example() or run_consumer_example().")
