import csv
import os
import logging
from collections import defaultdict

# Setup logging
logging.basicConfig(level=logging.INFO, format='%(asctime)s - %(levelname)s - %(message)s')

# Define the path to your CSV files and get a list of them
path = "/path/to/csv/files"

try:
    csv_files = [f for f in os.listdir(path) if f.endswith('_Lavender_usused_topics.csv')]
except FileNotFoundError:
    logging.error(f"Directory not found: {path}")
    raise
except PermissionError:
    logging.error(f"No permission to read directory: {path}")
    raise

# If there are no CSV files, log a warning and exit
if not csv_files:
    logging.warning(f"No CSV files found in directory: {path}")
    exit()

# Dictionary to count the number of files each topic is marked as unused
unused_counts = defaultdict(int)

# Iterate over all CSV files
for file_name in csv_files:
    logging.info(f"Processing file: {file_name}")
    try:
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
                unused_counts[topic_name] += 1
    except FileNotFoundError:
        logging.error(f"File not found: {file_name}")
        continue
    except PermissionError:
        logging.error(f"No permission to read file: {file_name}")
        continue

# Identify topics that are unused in all files
consistently_unused_topics = [topic for topic, count in unused_counts.items() if count == len(csv_files)]

# Output the unused topics to console
logging.info(f"Topics unused across all checked days: {', '.join(consistently_unused_topics)}")

# Save the consistently unused topics to a new CSV file
output_file = os.path.join(path, 'consistently_unused_topics.csv')
try:
    with open(output_file, 'w', newline='') as file:
        writer = csv.writer(file)
        # Writing header
        writer.writerow(["Topic Name", "Unused Count"])
        # Writing data
        for topic in consistently_unused_topics:
            writer.writerow([topic, unused_counts[topic]])
except PermissionError:
    logging.error(f"No permission to write to: {output_file}")
    raise

logging.info(f"Consistently unused topics saved to: {output_file}")
