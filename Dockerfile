FROM openjdk:11
MAINTAINER jieding
LABEL app="eureka" version="0.0.1" by="jieding"
COPY ./target/eureka-server-1.5.10.RELEASE.jar eurekaserver.jar
CMD java -jar eurekaserver.jar
