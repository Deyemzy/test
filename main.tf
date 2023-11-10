import boto3
import requests
import os
from datetime import datetime
import logging
from botocore.exceptions import ClientError

# Initialize a DynamoDB resource with Boto3
dynamodb = boto3.resource('dynamodb')

# Set up logging
logger = logging.getLogger()
logger.setLevel(logging.INFO)

# The name of the DynamoDB table
TABLE_NAME = os.environ.get('DYNAMODB_TABLE_NAME', 'ServiceStatusTable')

# GitHub Status API URL
GITHUB_STATUS_API_URL = 'https://www.githubstatus.com/api/v2/status.json'

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
        logger.info(f"Write to DynamoDB succeeded for {service_name}: {response}")
    except ClientError as e:
        logger.error(f"Error writing to DynamoDB for {service_name}: {e.response['Error']['Message']}")
        raise

def lambda_handler(event, context):
    try:
        # Make a GET request to the GitHub Status API
        response = requests.get(GITHUB_STATUS_API_URL)
        response.raise_for_status()  # Raises an HTTPError if the HTTP request returned an unsuccessful status code
        
        # Parse the response and write to DynamoDB
        data = response.json()
        status = data['status']['description']
        last_updated = data['page']['updated_at']
        
        write_to_dynamodb('GitHub', status, last_updated)
        
        return {
            'statusCode': 200,
            'body': 'Successfully updated the service status'
        }
    except requests.exceptions.RequestException as req_err:
        logger.error(f"Request to GitHub Status API failed: {req_err}")
        return {
            'statusCode': req_err.response.status_code if req_err.response else 503,
            'body': 'Failed to retrieve the service status'
        }
    except ClientError as db_err:
        logger.error(f"DynamoDB client error: {db_err}")
        return {
            'statusCode': 500,
            'body': 'Failed to write the service status to DynamoDB'
        }
    except Exception as e:
        logger.error(f"An unexpected error occurred: {str(e)}")
        return {
            'statusCode': 500,
            'body': 'An unexpected error occurred'
        }
