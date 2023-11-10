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
