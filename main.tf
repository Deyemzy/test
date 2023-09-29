from kafka import KafkaConsumer, TopicPartition
from kafka.admin import KafkaAdminClient, NewTopic
from kafka.errors import KafkaTimeoutError
import time
from datetime import datetime, timedelta

# Kafka broker and topic details
bootstrap_servers = "localhost:9092"  # Replace with your Kafka broker(s)
group_id = "consumer_group"  # Replace with your consumer group ID
lag_threshold = 100  # Define a threshold for consumer lag (adjust as needed)
inactive_threshold_days = 7  # Define a threshold for topic inactivity (adjust as needed)

# Create a Kafka consumer for monitoring consumer lag
consumer = KafkaConsumer(
    bootstrap_servers=bootstrap_servers,
    group_id=group_id,
    auto_offset_reset="latest"
)

# Create a Kafka AdminClient to list and delete topics
admin_client = KafkaAdminClient(bootstrap_servers=bootstrap_servers)

# List Kafka topics
topics = admin_client.list_topics()
topic_names = [topic for topic in topics if not topic.startswith("__")]

# Get current time
current_time = datetime.now()

# Iterate over topics and check for inactivity
for topic_name in topic_names:
    try:
        # Subscribe to the topic to get partitions
        consumer.subscribe([topic_name])
        partitions = consumer.assignment()

        # Calculate the earliest timestamp to consider a topic as inactive
        inactive_threshold = current_time - timedelta(days=inactive_threshold_days)

        # Check consumer lag for each partition
        total_lag = 0
        for partition in partitions:
            tp = TopicPartition(topic_name, partition)
            consumer.assign([tp])
            consumer.seek_to_end(tp)
            latest_offset = consumer.position(tp)
            consumer.seek_to_beginning(tp)
            earliest_offset = consumer.position(tp)
            consumer.seek_to_end(tp)
            current_offset = consumer.position(tp)
            consumer.seek(tp, current_offset)

            # Calculate consumer lag
            lag = latest_offset - current_offset

            # Check if the topic has been inactive for the specified days
            if earliest_offset == current_offset:
                last_activity = inactive_threshold
            else:
                last_activity = datetime.utcfromtimestamp(
                    consumer.timestamp(tp, earliest_offset) / 1000.0
                )

            if lag > lag_threshold:
                print(
                    f"Topic '{topic_name}' Partition {partition} has high lag ({lag} messages)."
                )
                print(
                    f"Last activity for Partition {partition}: {last_activity}"
                )

        # If the total lag is below the threshold and there's no recent activity, consider the topic for deletion
        if total_lag <= lag_threshold and last_activity < inactive_threshold:
            print(f"Topic '{topic_name}' is potentially unused and can be deleted.")
            # Uncomment the line below to delete the topic
            # admin_client.delete_topics(topic_names=[topic_name])

    except KafkaTimeoutError:
        print(f"Timeout while checking topic '{topic_name}'.")
    except Exception as e:
        print(f"Error checking topic '{topic_name}': {str(e)}")

# Close the Kafka consumer and AdminClient
consumer.close()
admin_client.close()
