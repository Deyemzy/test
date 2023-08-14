AWSTemplateFormatVersion: "2010-09-09"
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
