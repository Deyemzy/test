import boto3
import requests
import os
from datetime import datetime
from botocore.exceptions import ClientError

# Initialize a DynamoDB resource with Boto3
dynamodb = boto3.resource('dynamodb')

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
                'Timestamp': datetime.now().isoformat()
            }
        )
        return response
    except ClientError as e:
        print(f"An error occurred: {e.response['Error']['Message']}")
        raise

def lambda_handler(event, context):
    try:
        # Make a GET request to the GitHub Status API
        response = requests.get(GITHUB_STATUS_API_URL)
        response.raise_for_status()  # Raises an HTTPError if the HTTP request returned an unsuccessful status code
        
        # Parse the response
        data = response.json()
        status = data['status']['description']
        last_updated = data['page']['updated_at']
        
        # Write the status information to DynamoDB
        db_response = write_to_dynamodb('GitHub', status, last_updated)
        print('Write to DynamoDB succeeded:', db_response)
        
        return {
            'statusCode': 200,
            'body': 'Successfully updated the service status'
        }
    except requests.exceptions.HTTPError as http_err:
        # Specific error handling for HTTP errors
        print(f'HTTP error occurred: {http_err}')
        return {
            'statusCode': response.status_code,
            'body': f'HTTP error occurred: {http_err}'
        }
    except requests.exceptions.ConnectionError as conn_err:
        # Specific error handling for Connection errors
        print(f'Connection error occurred: {conn_err}')
        return {
            'statusCode': 503,
            'body': f'Connection error occurred: {conn_err}'
        }
    except requests.exceptions.Timeout as timeout_err:
        # Specific error handling for Timeout errors
        print(f'Timeout error occurred: {timeout_err}')
        return {
            'statusCode': 504,
            'body': f'Timeout error occurred: {timeout_err}'
        }
    except requests.exceptions.RequestException as req_err:
        # Broad error handling for any RequestException that isn't caught by the above
        print(f'Request error occurred: {req_err}')
        return {
            'statusCode': 500,
            'body': f'Request error occurred: {req_err}'
        }
    except ClientError as db_err:
        # Error handling for DynamoDB client errors
        print(f'DynamoDB client error: {db_err}')
        return {
            'statusCode': 500,
            'body': f'DynamoDB client error: {db_err}'
        }
    except Exception as e:
        # A broad catch for any other exception types
        print(f'An unexpected error occurred: {e}')
        return {
            'statusCode': 500,
            'body': f'An unexpected error occurred: {e}'
        }
