FROM 190547127216.dkr.ecr.us-west-2.amazonaws.com/jdk11:latest
MAINTAINER jieding
LABEL app="eureka" version="0.0.1" by="jieding"
COPY ./target/eureka-server-1.5.10.RELEASE.jar eurekaserver.jar
CMD java -jar eurekaserver.jar
