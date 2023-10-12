# Iterate over all CSV files
for file_index, file_name in enumerate(csv_files, start=1):
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
                unused_counts[topic_name] += 7 + (file_index - 1)
    except FileNotFoundError:
        logging.error(f"File not found: {file_name}")
        continue
    except PermissionError:
        logging.error(f"No permission to read file: {file_name}")
        continue
    
    # Debug log to check the dictionary during processing
    logging.debug(f"Unused counts after processing {file_name}: {unused_counts}")

# Debug log to check the threshold and unused counts
logging.debug(f"Threshold for consistently unused topics: {7 + 9 * (len(csv_files) - 1)}")
logging.debug(f"Unused counts: {unused_counts}")

# Identify topics that are unused in all files
consistently_unused_topics = [topic for topic, count in unused_counts.items() if count == 7 + 9 * (len(csv_files) - 1)]
