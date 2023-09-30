import logging
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

# NOTE: Please do not expose your credentials directly in scripts. Consider using a safer method like environment variables or secret managers.
conf = {
    'bootstrap.servers': bootstrap_servers,
    'security.protocol': 'SASL_SSL',
    'sasl.mechanism': 'PLAIN',
    'sasl.username': 'YOUR_SASL_USERNAME',
    'sasl.password': 'YOUR_SASL_PASSWORD',
    'group.id': group_id,
    'auto.offset.reset': 'earliest'
}

consumer = Consumer(conf)
admin_client = AdminClient(conf)

metadata = admin_client.list_topics(timeout=10)
topic_names = [topic.topic for topic in metadata.topics.values() if topic.topic.startswith("tango.dev.crm")]

for topic_name in topic_names:
    logging.info(f"Checking topic: {topic_name}")

    # Fetch topic's partition details
    topic_metadata = admin_client.list_topics(topic=topic_name, timeout=10)
    partitions = topic_metadata.topics[topic_name].partitions.values()

    unused_partitions = 0
    for partition in partitions:
        tp = TopicPartition(topic_name, partition.id)

        # Get the earliest and latest offsets
        earliest_offset, current_offset = consumer.get_watermark_offsets(tp, timeout=1, cached=False)

        timestamp_info = consumer.committed([tp])
        if timestamp_info and len(timestamp_info) > 0:
            timestamp = timestamp_info[0].offset
            last_activity = datetime.utcfromtimestamp(timestamp / 1000.0)
        else:
            last_activity = None

        inactive_threshold_date = datetime.utcnow() - timedelta(days=inactive_threshold_days)
        if earliest_offset == current_offset and last_activity and last_activity < inactive_threshold_date:
            unused_partitions += 1

    if unused_partitions == len(partitions):
        logging.warning(f"Topic '{topic_name}' seems unused. Consider deleting.")

consumer.close()
