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
