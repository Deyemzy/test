AWSTemplateFormatVersion: '2010-09-09'
Description: CloudFormation Template to Create a Test Windows EC2 Server

Parameters:
  InstanceType:
    Description: EC2 instance type for the test server
    Type: String
    Default: t3.medium
    AllowedValues: [t2.medium, t3.medium, t3.large, t3.xlarge]
  KeyPairName:
    Description: Name of the existing key pair for RDP access
    Type: AWS::EC2::KeyPair::KeyName
  VpcId:
    Description: VPC ID where the instance will be deployed
    Type: AWS::EC2::VPC::Id
  SubnetId:
    Description: Subnet ID for the instance
    Type: AWS::EC2::Subnet::Id
  AdminPassword:
    Description: Administrator Password for the test instance
    Type: String
    NoEcho: true

Resources:
  TestWindowsInstance:
    Type: AWS::EC2::Instance
    Properties:
      InstanceType: !Ref InstanceType
      ImageId: ami-0f2c2a6a09e3e4b6c  # Replace with the correct AMI for Windows Server in your region
      KeyName: !Ref KeyPairName
      SubnetId: !Ref SubnetId
      SecurityGroupIds: 
        - !Ref TestWindowsSecurityGroup
      UserData: 
        Fn::Base64: !Sub |
          <powershell>
          # Set Administrator Password
          net user Administrator ${AdminPassword}
          
          # Install required features
          Install-WindowsFeature -Name AD-Domain-Services -IncludeManagementTools
          
          # Configure DNS to point to your Domain Controller
          Set-DnsClientServerAddress -InterfaceAlias "Ethernet" -ServerAddresses "172.25.48.62"

          # Join the domain
          Add-Computer -DomainName "dmgallery.com" -Credential (New-Object PSCredential("dmgallery.com\Administrator", (ConvertTo-SecureString "${AdminPassword}" -AsPlainText -Force))) -Restart
          </powershell>
      Tags:
        - Key: Name
          Value: Test-Windows-AD-Client
TestWindowsSecurityGroup:
    Type: AWS::EC2::SecurityGroup
    Properties:
      GroupDescription: Allow RDP and ICMP traffic for testing
      VpcId: !Ref VpcId
      SecurityGroupIngress:
        - IpProtocol: tcp
          FromPort: 3389
          ToPort: 3389
          CidrIp: 0.0.0.0/0
        - IpProtocol: icmp
          FromPort: -1
          ToPort: -1
          CidrIp: 0.0.0.0/0
      Tags:
        - Key: Name
          Value: Test-Windows-SG
