import logging
import time
from confluent_kafka import Consumer, TopicPartition
from confluent_kafka.admin import AdminClient
from datetime import datetime, timedelta

# Setting up logging
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
    'auto.offset.reset': 'earliest'
}

consumer = Consumer(conf)
admin_client = AdminClient(conf)

metadata = admin_client.list_topics(timeout=10)
topic_names = [topic for topic in metadata.topics if topic.startswith("tango.dev")]

current_time = datetime.now()
inactive_threshold = current_time - timedelta(days=inactive_threshold_days)

for topic_name in topic_names:
    logging.info(f"Checking topic: {topic_name}")
    
    consumer.subscribe([topic_name])
    time.sleep(2)  # Allow time for partition assignment
    
    partitions = consumer.assignment()
    if not partitions:
        logging.warning(f"No partitions assigned for topic {topic_name}. Skipping.")
        continue

    unused_partitions = 0
    for partition in partitions:
        tp = TopicPartition(topic_name, partition.partition)
        
        consumer.seek_to_beginning(tp)
        earliest_offset = consumer.position(tp)
        
        consumer.seek_to_end(tp)
        current_offset = consumer.position(tp)

        timestamp = consumer.committed(tp)
        last_activity = datetime.utcfromtimestamp(timestamp.timestamp/1000.0) if timestamp else None
        
        if earliest_offset == current_offset and last_activity and last_activity < inactive_threshold:
            unused_partitions += 1

    if unused_partitions == len(partitions):
        logging.warning(f"Topic '{topic_name}' seems unused. Consider deleting.")

consumer.close()
