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
