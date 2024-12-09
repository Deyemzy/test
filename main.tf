aws dynamodb create-table \
    --table-name ServiceStatusTable \
    --attribute-definitions \
        AttributeName=ServiceName,AttributeType=S \
        AttributeName=Timestamp,AttributeType=S \
    --key-schema \
        AttributeName=ServiceName,KeyType=HASH \
        AttributeName=Timestamp,KeyType=RANGE \
    --provisioned-throughput \
        ReadCapacityUnits=1,WriteCapacityUnits=1 \
    --endpoint-url http://localhost:8000



mkdir -p requests_layer/python
cd requests_layer/python
pip install requests -t .
cd ..
zip -r requests_layer.zip python
aws lambda publish-layer-version --layer-name requests-layer --zip-file fileb://requests_layer.zip --compatible-runtimes python3.8


import requests
import urllib3
import logging

logger = logging.getLogger()
logger.setLevel(logging.INFO)

def lambda_handler(event, context):
    logger.info(f"Requests version: {requests.__version__}")
    logger.info(f"urllib3 version: {urllib3.__version__}")
    return {
        'statusCode': 200,
        'body': 'Version check executed successfully!'
    }




import boto3
import requests
import os
import logging
import xml.etree.ElementTree as ET
from datetime import datetime
from botocore.exceptions import ClientError

# Initialize a DynamoDB resource with Boto3
dynamodb = boto3.resource('dynamodb')

# Set up logging
logger = logging.getLogger()
logger.setLevel(logging.INFO)

# DynamoDB Table Name
TABLE_NAME = os.environ.get('DYNAMODB_TABLE_NAME', 'ServiceStatusTable')

# AWS Service Health Dashboard RSS Feed URL
AWS_STATUS_RSS_URL = 'https://status.aws.amazon.com/rss/all.rss'

# List of AWS services to monitor
SERVICES_TO_MONITOR = ['S3', 'EC2', 'Lambda', 'DynamoDB', 'AppSync']

def write_to_dynamodb(service_name, status, last_updated):
    item = {
        'ServiceName': service_name,
        'Status': status,
        'LastUpdated': last_updated,
        'Timestamp': datetime.utcnow().isoformat()
    }
    logger.info(f"Preparing to write item to DynamoDB: {item}")
    table = dynamodb.Table(TABLE_NAME)
    try:
        response = table.put_item(Item=item)
        logger.info(f"Response from DynamoDB: {response}")
    except ClientError as e:
        logger.error(f"Error in DynamoDB operation: {e.response['Error']['Message']}")
        raise
    except Exception as e:
        logger.error(f"Unexpected error: {e}")
        raise



def is_service_of_interest(title):
    try:
        for service in SERVICES_TO_MONITOR:
            if service in title:
                return True
        return False
    except Exception as e:
        logger.error(f"Error while filtering services: {e}")
        raise

# ... [previous code]

def lambda_handler(event, context):
    try:
        response = requests.get(AWS_STATUS_RSS_URL)
        response.raise_for_status()

        # Print the raw response content for debugging
        logger.info(f"Raw API Response: {response.content}")

        root = ET.fromstring(response.content)
        for item in root.findall('.//item'):
            title = item.find('title').text
            pub_date = item.find('pubDate').text

            if is_service_of_interest(title):
                service_name = title.split(':')[0]  # Example for extracting service name
                status = title

                logger.info(f"Processing status update for {service_name}")
                write_to_dynamodb(service_name, status, pub_date)

        return {'statusCode': 200, 'body': 'Successfully updated AWS service status'}
    except requests.exceptions.RequestException as req_err:
        logger.error(f"Request to AWS RSS feed failed: {req_err}")
        return {'statusCode': req_err.response.status_code if req_err.response else 503, 'body': 'Failed to retrieve AWS service status'}
    except ET.ParseError as parse_err:
        logger.error(f"XML parsing error: {parse_err}")
        return {'statusCode': 500, 'body': 'Failed to parse RSS feed'}
    except Exception as e:
        logger.error(f"An unexpected error occurred: {str(e)}")
        return {'statusCode': 500, 'body': 'An unexpected error occurred'}




# ... [previous code]

def lambda_handler(event, context):
    try:
        response = requests.get(AWS_STATUS_RSS_URL)
        response.raise_for_status()

        root = ET.fromstring(response.content)
        for item in root.findall('.//item'):
            title = item.find('title').text
            pub_date = item.find('pubDate').text
            description = item.find('description').text  # Additional historical info may be in the description

            if is_service_of_interest(title):
                service_name = extract_service_name(title)  # Implement this function based on your parsing logic
                status = title  # or parse status from title/description

                logger.info(f"Processing historical status update for {service_name}")
                write_to_dynamodb(service_name, status, pub_date)

        return {'statusCode': 200, 'body': 'Successfully processed AWS service history'}
    except requests.exceptions.RequestException as req_err:
        logger.error(f"Request to AWS RSS feed failed: {req_err}")
        return {'statusCode': req_err.response.status_code if req_err.response else 503, 'body': 'Failed to retrieve AWS service history'}
    # ... [rest of the error handling code]

def extract_service_name(title):
    # Implement parsing logic to extract the service name from the title
    # This is a placeholder function and needs actual implementation based on the title format in the RSS feed
    return title.split(':')[0]

# ... [rest of the code]

--------------------------------------------



import boto3
import requests
import os
import logging
import xml.etree.ElementTree as ET
from datetime import datetime
from botocore.exceptions import ClientError

# Initialize a DynamoDB resource with Boto3
dynamodb = boto3.resource('dynamodb')

# Set up logging
logger = logging.getLogger()
logger.setLevel(logging.INFO)

# DynamoDB Table Name
TABLE_NAME = os.environ.get('DYNAMODB_TABLE_NAME', 'ServiceStatusTable')

# AWS Service Health Dashboard RSS Feed URL
AWS_STATUS_RSS_URL = 'https://status.aws.amazon.com/rss/all.rss'

def write_to_dynamodb(service_name, status, last_updated):
    table = dynamodb.Table(TABLE_NAME)
    try:
        response = table.put_item(
            Item={
                'ServiceName': service_name,
                'Status': status,
                'LastUpdated': last_updated,
                'Timestamp': datetime.utcnow().isoformat()
            }
        )
        logger.info(f"Write to DynamoDB succeeded for {service_name}")
    except ClientError as e:
        logger.error(f"Error writing to DynamoDB for {service_name}: {e.response['Error']['Message']}")
        raise

def extract_service_info(title):
    try:
        parts = title.split(' (')
        service_name = parts[0] if len(parts) > 0 else 'Unknown Service'
        region = parts[1].rstrip(')') if len(parts) > 1 else 'Unknown Region'
        
        # Combine service name and region
        full_service_name = f"{service_name} ({region})"

        return full_service_name
    except Exception as e:
        logger.error(f"Error extracting service info: {str(e)}")
        return 'Unknown Service'

# Pre-approved list of services to monitor
PRE_APPROVED_SERVICES = ["Amazon EC2 (N. Virginia)", "Amazon S3 (Ohio)", "Amazon Lambda (Oregon)"]

def is_service_of_interest(full_service_name):
    return full_service_name in PRE_APPROVED_SERVICES

def lambda_handler(event, context):
    try:
        response = requests.get(AWS_STATUS_RSS_URL)
        response.raise_for_status()

        root = ET.fromstring(response.content)
        for item in root.findall('.//item'):
            title = item.find('title').text if item.find('title') is not None else 'No Title'
            pub_date = item.find('pubDate').text if item.find('pubDate') is not None else 'No Date'

            full_service_name = extract_service_info(title)

            logger.info(f"Processing event for {full_service_name}")
            write_to_dynamodb(full_service_name, title, pub_date)

        return {'statusCode': 200, 'body': 'Successfully processed AWS service events'}
    except requests.exceptions.RequestException as req_err:
        logger.error(f"Request to AWS RSS feed failed: {req_err}")
        return {'statusCode': req_err.response.status_code if req_err.response else 503, 'body': 'Failed to retrieve AWS service events'}
    except ET.ParseError as parse_err:
        logger.error(f"XML parsing error: {parse_err}")
        return {'statusCode': 500, 'body': 'Failed to parse RSS feed'}
    except Exception as e:
        logger.error(f"An unexpected error occurred: {str(e)}")
        return {'statusCode': 500, 'body': 'An unexpected error occurred'}




------------------

import boto3
import requests
import os
import logging
import xml.etree.ElementTree as ET
import re
from datetime import datetime
from botocore.exceptions import ClientError

# Initialize a DynamoDB resource with Boto3
dynamodb = boto3.resource('dynamodb')

# Set up logging
logger = logging.getLogger()
logger.setLevel(logging.INFO)

# DynamoDB Table Name
TABLE_NAME = os.environ.get('DYNAMODB_TABLE_NAME', 'ServiceStatusTable')

# AWS Service Health Dashboard RSS Feed URL
AWS_STATUS_RSS_URL = 'https://status.aws.amazon.com/rss/all.rss'

# Regex pattern for extracting service name and region
PATTERN = r'^(.*?)\s+\((.*?)\)'  # Assumes format: 'Service Name (Region)'

def extract_service_info(title):
    match = re.match(PATTERN, title)
    if match:
        return match.group(1), match.group(2)  # Service name, Region
    else:
        logger.warning(f"Unable to extract service name and region from title: {title}")
        return 'Unknown Service', 'Unknown Region'

def write_to_dynamodb(service_name, status, last_updated, description, region):
    table = dynamodb.Table(TABLE_NAME)
    item = {
        'ServiceName': service_name,
        'Status': status,
        'LastUpdated': last_updated,
        'Description': description,
        'Region': region,
        'Timestamp': datetime.utcnow().isoformat()
    }
    
    try:
        # Log the item details
        logger.info(f"Updating DynamoDB with item: {item}")

        # Write the item to DynamoDB
        response = table.put_item(Item=item)
        logger.info(f"Write to DynamoDB succeeded for {service_name} in {region}")
    except ClientError as e:
        logger.error(f"Error writing to DynamoDB for {service_name} in {region}: {e.response['Error']['Message']}")
        raise

def is_today(pub_date_str):
    try:
        pub_date = datetime.strptime(pub_date_str, '%a, %d %b %Y %H:%M:%S %Z')
        return pub_date.date() == datetime.utcnow().date()
    except ValueError as e:
        logger.error(f"Date parsing error: {str(e)}")
        return False

def lambda_handler(event, context):
    try:
        response = requests.get(AWS_STATUS_RSS_URL)
        response.raise_for_status()

        root = ET.fromstring(response.content)
        for item in root.findall('.//item'):
            title = item.find('title').text if item.find('title') is not None else 'No Title'
            pub_date_str = item.find('pubDate').text if item.find('pubDate') is not None else 'No Date'
            description = item.find('description').text if item.find('description') is not None else 'No Description'

            if is_today(pub_date_str):
                service_name, region = extract_service_info(title)
                logger.info(f"Processing today's event for {service_name} in {region}")
                write_to_dynamodb(service_name, title, pub_date_str, description, region)

        return {'statusCode': 200, 'body': 'Successfully processed today\'s AWS service events'}
    except requests.exceptions.RequestException as req_err:
        logger.error(f"Request to AWS RSS feed failed: {req_err}")
        return {'statusCode': req_err.response.status_code if req_err.response else 503, 'body': 'Failed to retrieve AWS service events'}
    except ET.ParseError as parse_err:
        logger.error(f"XML parsing error: {parse_err}")
        return {'statusCode': 500, 'body': 'Failed to parse RSS feed'}
    except Exception as e:
        logger.error(f"An unexpected error occurred: {str(e)}")
        return {'statusCode': 500, 'body': 'An unexpected error occurred'}




----
import boto3
import random
from datetime import datetime

# Initialize a DynamoDB resource
dynamodb = boto3.resource('dynamodb')

# Specify your DynamoDB table name
TABLE_NAME = 'YourTableName'
table = dynamodb.Table(TABLE_NAME)

def create_dummy_record(device_id):
    # Generate dummy data
    device_name = f"Device_{device_id}"
    location = random.choice(["United States", "Singapore", "Czech"])
    up_status = random.choice(["Online", "Offline"])
    connection_status = random.choice(["Connected", "Disconnected"])
    last_updated = datetime.now().strftime("%Y-%m-%d %H:%M:%S")
    timestamp = datetime.utcnow().isoformat()

    return {
        'DeviceName': device_name,
        'Location': location,
        'UpStatus': up_status,
        'ConnectionStatus': connection_status,
        'LastUpdated': last_updated,
        'Timestamp': timestamp
    }

def populate_table():
    for i in range(200):
        record = create_dummy_record(i)
        table.put_item(Item=record)

if __name__ == "__main__":
    populate_table()
    print("Table population completed.")

-------------------------------------------------------------------


import requests
import json
import os

# API URL
url = 'xxxx'

# API Token from environment variable or input
api_token = os.getenv('API_TOKEN') or input("Enter API Token: ")

# Headers
headers = {
    'Content-Type': 'application/json',
    'Accept': 'application/json',
    'X-AUTH-TOKEN': api_token
}

# Payload
payload = {
    "deviceld": [100497, 1005498, 92229, 92230, 90076, 90077, 93536, 93535],
    "timespanBetween": {
        "startTime": 1692688056000,
        "endTime": 1700000000000  # Replace with actual end time in Unix timestamp
    },
    "severity": [2, 3, 4]  # Severity levels for 'Critical', 'Error', and 'Warning'
}

# POST request
response = requests.post(url, headers=headers, data=json.dumps(payload))

# Checking the response
if response.status_code == 200:
    print("Success:", response.json())
else:
    print("Failed:", response.text)



AWSTemplateFormatVersion: '2010-09-09'
Description: CloudFormation Template to deploy Windows Server 2022 with AD role  

Parameters:  
  InstanceType:  
    Type: String  
    Default: m5a.large  
    Description: EC2 instance type  

  KeyName:  
    Type: AWS::EC2::KeyPair::KeyName  
    Description: Name of the existing KeyPair to enable RDP access  

  SubnetId:  
    Type: AWS::EC2::Subnet::Id  
    Description: The Subnet ID for the instance  

  SecurityGroupId:  
    Type: AWS::EC2::SecurityGroup::Id  
    Description: Security Group ID for the instance  

  ImageId:  
    Type: AWS::EC2::Image::Id  
    Description: AMI ID for Windows Server 2022  

Resources:  
  WindowsADServer:  
    Type: AWS::EC2::Instance  
    Properties:  
      InstanceType: !Ref InstanceType  
      KeyName: !Ref KeyName  
      SubnetId: !Ref SubnetId  
      SecurityGroupIds:  
        - !Ref SecurityGroupId  
      ImageId: !Ref ImageId  
      Tags:  
        - Key: Name  
          Value: Windows-Server-2022-AD  
      UserData:  
        Fn::Base64: !Sub |  

