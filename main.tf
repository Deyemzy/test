import logging
import time
from confluent_kafka import Consumer, TopicPartition
from confluent_kafka.admin import AdminClient
from datetime import datetime, timedelta

# Setup Logging Configuration
logging.basicConfig(level=logging.INFO, format='%(asctime)s - %(levelname)s - %(message)s')

# Kafka broker and topic details
bootstrap_servers = "pkc-n98pk.us-west-2.aws.confluent.cloud:9092"
group_id = "hub-template-job-orderrate"
lag_threshold = 100
inactive_threshold_days = 7

conf = {
    'bootstrap.servers': bootstrap_servers,
    'security.protocol': 'SASL_SSL',
    'sasl.mechanism': 'PLAIN',
    'sasl.username': 'WVRSK2IEPLMOKOP5',
    'sasl.password': 'dxHglglamGcxXne08Ac2o24ckZBaCmYzCLzyLiircTLmRQg4+l3bDYFBLAQLgmvY',
    'group.id': group_id,
    'auto.offset.reset': 'smallest'
}

consumer = Consumer(conf)
admin_client = AdminClient(conf)

metadata = admin_client.list_topics(timeout=10)
topic_names = [topic for topic in metadata.topics]

# Log topics and their partition counts
for topic, topic_metadata in metadata.topics.items():
    logging.info(f"Topic {topic} has {len(topic_metadata.partitions)} partitions.")

current_time = datetime.now()
inactive_threshold = current_time - timedelta(days=inactive_threshold_days)
last_activity = inactive_threshold

for topic_name in topic_names:
    logging.info(f"Subscribing to topic: {topic_name}")
    consumer.subscribe([topic_name])
    time.sleep(2)  # Sleep to allow time for assignment
    partitions = consumer.assignment()
    logging.info(f"Assigned partitions for topic {topic_name}: {partitions}")
    
    total_lag = 0
    for partition in partitions:
        tp = TopicPartition(topic_name, partition.partition)
        consumer.assign([tp])
        
        latest_offset = consumer.position(tp)
        consumer.seek_to_beginning(tp)
        earliest_offset = consumer.position(tp)
        consumer.seek_to_end(tp)
        current_offset = consumer.position(tp)

        lag = latest_offset - current_offset
        if earliest_offset == current_offset:
            last_activity = inactive_threshold
        else:
            timestamp = consumer.committed(tp)
            last_activity = datetime.utcfromtimestamp(timestamp/1000.0)

        if lag > lag_threshold:
            logging.warning(f"Topic '{topic_name}' Partition {partition.partition} has high lag ({lag} messages). Last activity for Partition {partition.partition}: {last_activity}")

        total_lag += lag

    if total_lag <= lag_threshold and last_activity < inactive_threshold:
        logging.info(f"Topic '{topic_name}' is potentially unused and can be deleted.")
        # Uncomment the line below to delete the topic if needed
        # admin_client.delete_topics([topic_name])

consumer.close()
logging.info("Consumer closed.")
