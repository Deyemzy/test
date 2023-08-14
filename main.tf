n  AWSTemplateFormatVersion: "2010-09-09"
Description: An IAM role template for StackSet deployment

Resources:
  CrossAccountRole:
    Type: "AWS::IAM::Role"
    Properties:
      AssumeRolePolicyDocument:
        Version: "2012-10-17"
        Statement:
          - Effect: "Allow"
            Principal:
              AWS:
                - "<Management_Account_ID>"
            Action:
              - "sts:AssumeRole"
      Path: "/"
      RoleName: "MyCrossAccountRole"






Created a StackSet in the management account to centrally manage and deploy IAM roles across multiple linked AWS accounts. This StackSet includes a CloudFormation template defining the desired IAM roles, policies, and trust relationships. By deploying this StackSet, we can ensure consistent IAM role configurations in each linked account, enhancing security and operational efficiency.
