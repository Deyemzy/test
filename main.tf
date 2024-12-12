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
Weekly Work Summary
1. Resolved Server Connectivity Issues:

Worked on a Windows server hosted in the cloud to ensure it was running smoothly.
Fixed connection issues by checking security settings and confirming the server’s alignment with organizational standards.
2. Research on Trump 2.0 Policy Changes:

Researched 10 major policy changes expected under Trump 2.0, focusing on their impact on government contracts and healthcare opportunities.
Organized findings into a clear report using insights from trusted sources like PwC, Forbes, and the Immigration Reform Law Institute.
3. Team Collaboration on Process Improvements:

Participated in a session discussing improvements for pilot workflows and administrative processes.
Contributed to planning better ways to manage applications, track progress, and solve configuration issues.
4. Streamlining User Access with Directory Services:

Set up a system to ensure secure and smooth user access for a platform called MuleSoft.
Tested and confirmed that users can connect successfully, laying the groundwork for further improvements
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
