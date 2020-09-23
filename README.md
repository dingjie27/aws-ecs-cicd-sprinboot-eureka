# aws-ecs-cicd-sprinboot-eureka


参考文档：https://docs.aws.amazon.com/codebuild/latest/userguide/sample-ecr.html

1、如果是使用自定义的base image，并且要把最终结果页推送到ecr。那么首先要创建一个
CodeBuild iam role，定义一些可以读取ecr和push到ecr的，以及涉及ecr鉴权的policy。policy的内容如下：
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Sid": "CloudWatchLogsPolicy",
            "Effect": "Allow",
            "Action": [
                "logs:CreateLogGroup",
                "logs:CreateLogStream",
                "logs:PutLogEvents"
            ],
            "Resource": [
                "*"
            ]
        },
        {
            "Sid": "CodeCommitPolicy",
            "Effect": "Allow",
            "Action": [
                "codecommit:GitPull"
            ],
            "Resource": [
                "*"
            ]
        },
        {
            "Sid": "S3GetObjectPolicy",
            "Effect": "Allow",
            "Action": [
                "s3:GetObject",
                "s3:GetObjectVersion"
            ],
            "Resource": [
                "*"
            ]
        },
        {
            "Sid": "S3PutObjectPolicy",
            "Effect": "Allow",
            "Action": [
                "s3:PutObject"
            ],
            "Resource": [
                "*"
            ]
        },
        {
            "Sid": "ECRPullPolicy",
            "Effect": "Allow",
            "Action": [
                "ecr:BatchCheckLayerAvailability",
                "ecr:GetDownloadUrlForLayer",
                "ecr:BatchGetImage"
            ],
            "Resource": [
                "*"
            ]
        },
        {
            "Sid": "ECRPushPolicy",
            "Effect": "Allow",
            "Action": [
                "ecr:CompleteLayerUpload",
                "ecr:InitiateLayerUpload",
                "ecr:PutImage",
                "ecr:UploadLayerPart"
            ],
            "Resource": [
                "*"
            ]
        },
        {
            "Sid": "ECRAuthPolicy",
            "Effect": "Allow",
            "Action": [
                "ecr:GetAuthorizationToken"
            ],
            "Resource": [
                "*"
            ]
        }
    ]
}
参考：https://docs.aws.amazon.com/codebuild/latest/userguide/setting-up.html#setting-up-service-role

2、在iam的role中点击创建role，把role的service选择为codebuild，把刚刚创建好的policy添加上去。

3、进入codebuild的页面，开始创建project。其他的配置按照自己的需求来配置。
需要注意两部分，
3.1、在environment images中选择custom image，这个部分用来定义我们的编译环境，因为示例的项目是基于java11编写的，所以选择ubuntu，standard2.0版本，因为这个版本可以在编译用的buildspec.yml中指定运行时环境为openjdk11。具体可以参考链接：https://docs.aws.amazon.com/codebuild/latest/userguide/build-env-ref-available.html
3.2、在环境的配置中选择刚才定义的role


4、编写自己的buildspec.yml
要注意的是在intall阶段需要标注打包用的docker的运行环境，参考链接：
https://docs.aws.amazon.com/codebuild/latest/userguide/build-env-ref-available.html
关于install中runtime docker的选择可以参考链接：https://docs.aws.amazon.com/codebuild/latest/userguide/build-spec-ref.html#runtime-versions-buildspec-file
在pre_build中标红的部分是需要先登陆到ecr去，如果没有这部分，在ecr进行push的时候会出错。

version: 0.2

phases:
  install:
    runtime-versions:
      java: openjdk11
  pre_build:
    commands:
      - echo Doing mvn test...
      - mvn test
      - echo Logging in to Amazon ECR...
      - $(aws ecr get-login --no-include-email --region us-east-1)
  build:
    commands:
      - echo Build started on `date`
      - mvn package
      - docker build -t eureka .
      - docker tag eureka:latest 687804506828.dkr.ecr.us-east-1.amazonaws.com/eureka:latest
  post_build:
    commands:
      - echo Build completed on `date`
      - docker push 687804506828.dkr.ecr.us-east-1.amazonaws.com/eureka:latest

5、编写自己的Dockerfile
demo链接：https://github.com/dingjie27/eureka/blob/master/Dockerfile
注意：from中要写自己想选取的自定义的base image，这个链接是ecr中已经上传好的base image的地址。
FROM 687804506828.dkr.ecr.us-east-1.amazonaws.com/javademo:latest
MAINTAINER jieding
LABEL app="eureka" version="0.0.1" by="jieding"
COPY ./target/eureka-server-1.5.10.RELEASE.jar eurekaserver.jar
CMD java -jar eurekaserver.jar

6、为了成功的使用这个image，需要在ecr中选择repositories，选择自己放base image的repository，选择里边的permission，添加如下内容。否则在拉取image的时候会报错。
{
  "Statement": [
    {
      "Action": [
        "ecr:BatchCheckLayerAvailability",
        "ecr:BatchGetImage",
        "ecr:GetDownloadUrlForLayer"
      ],
      "Principal": {
        "Service": [
          "codebuild.amazonaws.com"
        ]
      },
      "Effect": "Allow",
      "Sid": "CodeBuildAccess"
    }
  ],
  "Version": "2008-10-17"
}
7、之后可以执行code build，一般可以推送成功


#codedeploy系列使用ecr中的镜像部署到ecs fargate

codedeploy使用步骤

1、进入codedeploy，创建一个application
2、 在iam服务中选择role，为codedeploy服务创建一个可以deploy到ecs的角色，具体创建的方式如下：https://docs.aws.amazon.com/codedeploy/latest/userguide/getting-started-create-service-role.html
假设我们创建好的服务叫做CodeDeployServiceRole
3、接下来我们需要开始创建一个deployment，在创建一个deployment之前，有如下资源需要被创建好：
-----------------------------------------------------------------------------------------
3.1 在ec2的lb的部分设置如下内容：
3.1.1、Application Load Balancer or Network Load Balancer 
注意，如果是部署到ecs，那么建议使用alb，同时在alb创建的时候Target type需要选择ip而不是instance。然后可以直接跳过register阶段。
3.1.2、Production listener和Test listener (optional) 
设置lb的监听器(可以在创建ecs service的再创建，不一定要在此时创建)
3.1.3、Two target groups 
是alb的两个target group，一个是用来接受流量的，用来备用的task的（可以此时只创建一个，另一个在创建ecs service的时候创建）
-----------------------------------------------------------------------------------------
-----------------------------------------------------------------------------------------
3.2 在ecs只能够的lb的部分设置如下内容：
3.2.1、创建一个Amazon ECS cluster
3.2.2、创建一个Amazon ECS task definition
3.2.3、创建一个Amazon ECS service 
在ecs的cluster中创建一个service，service的 配置部分主要内容如下：



然后在service设置中注意选择您的安全组和您刚才在设置好的target group等信息。
4、创建你的codedeploy application中创建deployment group，此处并没有太多需要注意的，部分截图如下：



5、在deployment group中创建deployment，关键部分截图如下：



一个appspec.yml的demo：（标红部分请根据自己的实际情况调整）
version: 0.0

Resources:
  - TargetService:
      Type: AWS::ECS::Service
      Properties:
        TaskDefinition: "arn:aws:ecs:us-east-1:687804506828:task-definition/eureka:1"
        LoadBalancerInfo: 
          ContainerName: "eureka"
          ContainerPort: 80
