import csv
import os
import logging
from collections import defaultdict
from datetime import datetime, timedelta

# Set up logging configuration
logging.basicConfig(level=logging.INFO, format='%(asctime)s - %(levelname)s - %(message)s')

# Define the path to your CSV files and get a list of them
path = "/path/to/csv/files"
csv_files = [f for f in os.listdir(path) if f.endswith('_Lavender_usused_topics.csv')]
logging.info(f"Found {len(csv_files)} CSV files.")

# Dictionary to count the number of files each topic is marked as unused and track the first and last dates it was unused
unused_topics_info = defaultdict(lambda: {"count": 0, "first_date": None, "last_date": None})

# Iterate over all CSV files
for file_name in csv_files:
    date_str = file_name.split('_')[0]  # Assumes the date is the first part of the filename before an underscore
    file_date = datetime.strptime(date_str, "%Y%m%d")  # Adjust the format accordingly
    with open(os.path.join(path, file_name), 'r') as file:
        reader = csv.reader(file)
        # Skip headers
        for _ in range(5): next(reader)
        # Process topic entries
        for row in reader:
            if not row:  # Skip empty rows
                continue
            if "Total unused topics" in row[0]:  # Stop when summary lines are reached
                break
            topic_name, _ = row
            unused_topics_info[topic_name]["count"] += 1
            if unused_topics_info[topic_name]["first_date"] is None or file_date < unused_topics_info[topic_name]["first_date"]:
                unused_topics_info[topic_name]["first_date"] = file_date
            if unused_topics_info[topic_name]["last_date"] is None or file_date > unused_topics_info[topic_name]["last_date"]:
                unused_topics_info[topic_name]["last_date"] = file_date

# Identify topics that are unused in all files
consistently_unused_topics = [(topic, info["first_date"], info["last_date"]) for topic, info in unused_topics_info.items() if info["count"] == len(csv_files)]

# Output the unused topics
logging.info("Topics unused across all checked days:")
for topic, first_date, last_date in consistently_unused_topics:
    logging.info(f"- {topic}, from {first_date.strftime('%Y-%m-%d')} to {last_date.strftime('%Y-%m-%d')}")

# Save to CSV
output_filename = "consistently_unused_topics.csv"
with open(output_filename, 'w', newline='') as file:
    writer = csv.writer(file)
    writer.writerow(["Topic Name", "First Unused Date", "Last Unused Date", "Total Unused Days"])
    for topic, first_date, last_date in consistently_unused_topics:
        unused_days = (last_date - first_date).days + 1
        writer.writerow([topic, first_date.strftime('%Y-%m-%d'), last_date.strftime('%Y-%m-%d'), unused_days])
logging.info(f"Unused topics data saved to {output_filename}.")
