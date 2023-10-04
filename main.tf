import logging
import csv
import pytz
from confluent_kafka import Consumer, TopicPartition
from confluent_kafka.admin import AdminClient
from datetime import datetime, timedelta

# Setting up logging
logging.basicConfig(level=logging.INFO, format='%(asctime)s - %(levelname)s - %(message)s')

# Kafka broker and topic details
bootstrap_servers = "your_kafka_broker"
group_id = "your_group_id"
lag_threshold = 100
inactive_threshold_days = 7

# TODO: Use secure ways to handle credentials like environment variables or secret managers.
conf = {
    'bootstrap.servers': bootstrap_servers,
    'security.protocol': 'SASL_SSL',
    'sasl.mechanism': 'PLAIN',
    'sasl.username': 'your_username',
    'sasl.password': 'your_password',
    'group.id': group_id,
    'auto.offset.reset': 'earliest'
}

def get_unused_topics(admin_client, consumer):
    metadata = admin_client.list_topics(timeout=10)
    topic_names = [topic.topic for topic in metadata.topics.values() if topic.topic.startswith("tango.dev.crm")]
    unused_topics_list = []
    total_topics_count = 0
    total_partitions_count = 0

    for topic_name in topic_names:
        logging.info(f"Checking topic: {topic_name}")
        topic_metadata = admin_client.list_topics(topic=topic_name, timeout=10)
        partitions = topic_metadata.topics[topic_name].partitions.values()
        total_topics_count += 1
        total_partitions_count += len(partitions)
        logging.info(f"Topic '{topic_name}' has {len(partitions)} partitions!")
        
        unused_partitions = check_unused_partitions(consumer, partitions, topic_name, inactive_threshold_days)
        
        if unused_partitions == len(partitions):
            logging.warning(f"Topic '{topic_name}' is potentially unused and can be deleted.")
            unused_topics_list.append((topic_name, len(partitions)))

    return unused_topics_list, total_topics_count, total_partitions_count

def check_unused_partitions(consumer, partitions, topic_name, inactive_threshold_days):
    unused_partitions = 0
    
    for partition in partitions:
        tp = TopicPartition(topic_name, partition.id)
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
    
    return unused_partitions

def save_to_csv(filename, unused_topics_list, total_data, current_datetime):
    with open(filename, 'w', newline='') as file:
        writer = csv.writer(file)
        writer.writerow(["Script Run Date", current_datetime])
        writer.writerow([])
        writer.writerow(["Topic Name", "Partition Count"])
        
        for topic, partition_count in unused_topics_list:
            writer.writerow([topic, partition_count])
        
        writer.writerow([])
        writer.writerow(["Total unused topics", total_data[0]])
        writer.writerow(["Total unused partitions", total_data[1]])
        writer.writerow(["Total topics in the cluster", total_data[2]])
        writer.writerow(["Total partitions in the cluster", total_data[3]])
        
        logging.info(f"List of unused topics saved to {filename}")
        logging.info(f"Total unused topics: {total_data[0]}")
        logging.info(f"Total unused partitions: {total_data[1]}")
        logging.info(f"Total topics in cluster: {total_data[2]}")
        logging.info(f"Total partitions in cluster: {total_data[3]}")
        logging.info(f"Script run date: {current_datetime}")

if __name__ == "__main__":
    consumer = Consumer(conf)
    admin_client = AdminClient(conf)

    unused_topics_list, total_topics_count, total_partitions_count = get_unused_topics(admin_client, consumer)
    unused_topics_count = len(unused_topics_list)
    unused_partitions_count = sum([partitions for _, partitions in unused_topics_list])
    
    eastern = pytz.timezone('US/Eastern')
    current_datetime = datetime.now(eastern).strftime("%A, %Y-%m-%d %H:%M:%S")
    file_date = datetime.now(eastern).strftime("%Y_%m_%d")
    
    filename = f"{file_date}_unused_topics.csv"
    total_data = (unused_topics_count, unused_partitions_count, total_topics_count, total_partitions_count)
    
    save_to_csv(filename, unused_topics_list, total_data, current_datetime)
    
    consumer.close()
