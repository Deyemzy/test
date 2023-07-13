import boto3
import json

def create_iam_policy(policy_name, policy_description, policy_document):
    iam_client = boto3.client('iam')

    response = iam_client.create_policy(
        PolicyName=policy_name,
        PolicyDocument=json.dumps(policy_document),
        Description=policy_description
    )

    return response['Policy']['Arn']

def create_iam_role(role_name, role_description, trust_relationship):
    iam_client = boto3.client('iam')

    response = iam_client.create_role(
        RoleName=role_name,
        AssumeRolePolicyDocument=json.dumps(trust_relationship),
        Description=role_description
    )

    return response['Role']['Arn']

def attach_policy_to_role(policy_arn, role_name):
    iam_client = boto3.client('iam')

    response = iam_client.attach_role_policy(
        PolicyArn=policy_arn,
        RoleName=role_name
    )

    return response['ResponseMetadata']['HTTPStatusCode']

# Usage example
policy_name = 'MyPolicy'
policy_description = 'My custom IAM policy'
role_name = 'MyRole'
role_description = 'My custom IAM role'
account_id = 'YOUR_ACCOUNT_ID'
external_id = 'YOUR_EXTERNAL_ID'

trust_relationship = {
    'Version': '2012-10-17',
    'Statement': [
        {
            'Effect': 'Allow',
            'Principal': {
                'AWS': f'arn:aws:iam::{account_id}:root'
            },
            'Action': 'sts:AssumeRole',
            'Condition': {
                'StringEquals': {
                    'sts:ExternalId': external_id
                }
            }
        }
    ]
}

policy_document = {
    "Version": "2012-10-17",
    "Statement": [
        {
            "Effect": "Allow",
            "Action": [
                "appstream:Describe*",
                "appstream:List*",
                "autoscaling:Describe*",
                # Add other actions here
            ],
            "Resource": "*"
        }
    ]
}

policy_arn = create_iam_policy(policy_name, policy_description, policy_document)
role_arn = create_iam_role(role_name, role_description, trust_relationship)
attach_policy_to_role(policy_arn, role_name)
