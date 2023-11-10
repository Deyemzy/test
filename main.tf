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
