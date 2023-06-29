import logging
import boto3
import requests
import json
from requests_aws4auth import AWS4Auth
import datetime

# Configure logging
logging.basicConfig(level=logging.INFO, format='%(asctime)s - %(levelname)s - %(message)s')
logger = logging.getLogger(__name__)

def get_opensearch_endpoint(domain_name):
    region = 'us-west-2'
    service = 'es'
    session = boto3.Session(profile_name='yemi-opensearch-test')
    credentials = session.get_credentials()
    awsauth = AWS4Auth(credentials.access_key, credentials.secret_key, region, service, session_token=credentials.token)
    client = session.client('es')

    # Retrieve domain information
    response = client.describe_elasticsearch_domain(DomainName=domain_name)

    # Extract the endpoint URL from the response
    endpoint = response['DomainStatus']['Endpoints']['vpc']
    host = f"https://{endpoint}/"

    return host

def register_repository(awsauth, url, repository_name, bucket_name, execution_role_arn):
    # Check if the repository already exists
    r = requests.get(url, auth=awsauth)
    if r.status_code == 200:
        repositories = r.json().keys()
        if repository_name in repositories:
            logger.info(f"Repository '{repository_name}' already exists.")
            return

    date_prefix = datetime.datetime.now().strftime('%Y-%m-%d')

    # Register repository
    payload = {
        "type": "s3",
        "settings": {
            "bucket": bucket_name,
            "region": "us-west-2",
            "role_arn": execution_role_arn,
            "base_path": f"{repository_name}/snapshots/{date_prefix}"
        }
    }

    headers = {"Content-Type": "application/json"}

    r = requests.put(url, auth=awsauth, json=payload, headers=headers)

    logger.info("register_repository %s", r.status_code)
    logger.info("register_repository %s", r.text)

def capture_snapshot(url, awsauth, retention_period, domain_name):
    logger.info('Taking snapshot of all indices')
    date_prefix = datetime.datetime.now().strftime('%Y-%m-%d')
    snapshot_name = f"{date_prefix}-all-indices"
    url += f"/{snapshot_name}"

    payload = {
        "indices": "all",
        "ignore_unavailable": 'true',
        "include_global_state": 'false',
        "partial": 'false',
        "retention_period": f"{retention_period}d"
    }

    logger.info('%s Snapshot is created by this name', url)

    headers = {"Content-Type": "application/json"}

    try:
        r = requests.put(url, auth=awsauth, json=payload, headers=headers)
        r.raise_for_status()
        logger.info('Snapshot creation successful. Response: %s', r.text)
    except requests.exceptions.RequestException as e:
        logger.error("Failed to create snapshot. Error: %s", str(e))

def cleanup_old_snapshots(url, awsauth, retention_period, domain_name):
    logger.info('Cleaning up old snapshots')
    url += f"/"

    try:
        r = requests.get(url, auth=awsauth)
        r.raise_for_status()
        snapshots = r.json().keys()
        today = datetime.datetime.now()
        deleted_snapshots = 0
        for snapshot in snapshots:
            if not snapshot.endswith('-all-indices'):
                continue
            snapshot_date_str = snapshot.replace('-all-indices', '')
            snapshot_date = datetime.datetime.strptime(snapshot_date_str, '%Y-%m-%d')
            delta = today - snapshot_date
            if delta.days > retention_period:
                logger.info(f"Deleting old snapshot: {snapshot}")
                delete_url = f"{url}/{snapshot}"
                r = requests.delete(delete_url, auth=awsauth)
                r.raise_for_status()
                logger.info(f"Deleted snapshot: {snapshot}")
                deleted_snapshots += 1
        if deleted_snapshots == 0:
            logger.info("No old snapshots found to delete.")
    except requests.exceptions.RequestException as e:
        logger.error("Failed to retrieve or delete snapshots. Error: %s", str(e))

def lambda_handler(event, context):
    logger.info(event)

    # Getting environment and domain names from the event configuration
    environment_name = event['name']  # prd, dev, stg, qat
    domain_name = event['domain_name']

    # Generate OpenSearch host using the domain name
    host = get_opensearch_endpoint(domain_name)

    # Construct the URL for repository registration and snapshot capture
    path = f'_snapshot/snapshots'
    url = host + path

    # Repository name
    repository_name = f"{domain_name}/{environment_name}"

    # Get team-specific S3 bucket name
    bucket_name = event.get('bucket_name', 'atlas-opensearch-backup')

    # Check if backup is enabled
    backup_enabled = event.get('backup', False)

    if backup_enabled:
        # Get execution role ARN
        execution_role_arn = 'arn:aws:iam::374217561360:role/OpensearchLambdaRole'

        # Register repository
        register_repository(awsauth, url, repository_name, bucket_name, execution_role_arn)

        # Retention period
        retention_period = int(event.get('retention_period', 7))

        # Take snapshots
        capture_snapshot(url, awsauth, retention_period, domain_name)

        # Cleanup old snapshots
        cleanup_old_snapshots(url, awsauth, retention_period, domain_name)
    else:
        logger.info("Backup is not enabled for this environment.")

    return True


if __name__ == '__main__':
    event = {
        'name': 'dev',
        'domain_name': 'common-services',
        'bucket_name': 'your-private-bucket-name',
        'backup': True,
        'retention_period': 7
    }
    context = None
    lambda_handler(event, context)
