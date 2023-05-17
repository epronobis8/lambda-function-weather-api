
# Requires an OpenWeather Account Sign-Up here & to Create an API Key:
https://home.openweathermap.org/users/sign_up

## To Deploy Infrastructure:
Terraform Plan
Terraform Apply

### Resources Created:
2 Lambda Functions
1 Lambda Roles & Permissions for CloudWatch & Parameter Store
SSM Paramter
VPC including Nat Gateway, IGW, SG, NACL, Routes Tables, Public Subnets, Private Subnet, etc.
EventBridge scheduler to Kick-off Lambda Functions
CloudWatch Logs

## Lambda Deployed in a VPC
If you created and specify a VPC for a Lambda Function, you are responsible for the configuration of the VPC including network access and security rules within the VPC. The VPC is visible to developers and monitoring is done at the VPC level. 


## Lambda Deployed without a VPC
If you do not specify a VPC for a Lambda Function, AWS is responsible for the configuration of the VPC within the Lambda Service including apply network access and security rules to everything within the VPC. These VPCs are not visible to customers, the configurations are maintained automatically, and monitoring is managed by the service. 

https://docs.aws.amazon.com/lambda/latest/operatorguide/networking-vpc.html

## Lambda ENIs

When you configure a Lambda function to access resources in an Amazon Virtual Private Cloud (Amazon VPC), Lambda assigns the function to a network interface. The network interfaces that Lambda creates can be deleted by the Lambda service only.

https://repost.aws/knowledge-center/lambda-eni-find-delete

