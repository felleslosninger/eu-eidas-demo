FROM alpine:latest as builder

# Install software
RUN apk add --no-cache zip unzip curl

WORKDIR /data

ARG EIDAS_NODE_VERSION=2.7.1
ARG EIDAS_NODE_URL=https://ec.europa.eu/digital-building-blocks/artifact/repository/eid/eu/eIDAS-node/${EIDAS_NODE_VERSION}/eIDAS-node-${EIDAS_NODE_VERSION}.zip

# Download eIDAS-Node Software
RUN curl ${EIDAS_NODE_URL} -o eIDAS-node-dl.zip

# Unzip eIDAS-Node Software
RUN unzip eIDAS-node-dl.zip && \
    unzip EIDAS-Binaries-Tomcat-*.zip
RUN unzip /data/TOMCAT/config.zip -d /tmp/

ENV config_path=/tmp/tomcat
RUN cd /tmp/tomcat

RUN sed -i 's/localhost:8080\/EidasNodeConnector/eidas-demo-cb:8081\/EidasNodeConnector/g' $config_path/connector/eidas.xml
RUN sed -i 's/localhost:8080\/SpecificConnector/eidas-demo-cb:8081\/SpecificConnector/g' $config_path/connector/eidas.xml
RUN sed -i 's/metadata.node.country">CA/metadata.node.country">CB/g' $config_path/connector/eidas.xml
RUN sed -i 's/metadata.node.country">CA/metadata.node.country">CB/g' $config_path/proxy/eidas.xml
RUN sed -i 's/service.countrycode">CA/service.countrycode">CB/g' $config_path/proxy/eidas.xml
RUN sed -i 's/localhost:8080/eidas-demo-cb:8081/g' $config_path/proxy/eidas.xml
RUN sed -i 's/localhost:8080\/SP/eidas-demo-cb:8081\/SP/g' $config_path/sp/sp.properties
RUN sed -i 's/localhost:8080/eidas-demo-cb:8081/g' $config_path/specificConnector/specificConnector.xml
RUN sed -i 's/localhost:8080/eidas-demo-cb:8081/g' $config_path/specificProxyService/specificProxyService.xml
RUN sed -i 's/DEMO-IDP/DEMO-IDP-CB/g' $config_path/idp/idp.properties

RUN sed -i 's/localhost:8080\/EidasNodeConnector\/ServiceProvider/eidas-demo-ca:8080\/EidasNodeConnector\/ServiceProvider/g' $config_path/sp/sp.properties
RUN sed -i 's/localhost:8081\/EidasNodeConnector\/ServiceProvider/eidas-demo-cb:8081\/EidasNodeConnector\/ServiceProvider/g' $config_path/sp/sp.properties
RUN sed -i 's/localhost:8080\/EidasNodeProxy\/ServiceMetadata/eidas-demo-ca:8080\/EidasNodeProxy\/ServiceMetadata/g' $config_path/connector/eidas.xml
RUN sed -i 's/localhost:8081\/EidasNodeProxy\/ServiceMetadata/eidas-demo-cb:8081\/EidasNodeProxy\/ServiceMetadata/g' $config_path/connector/eidas.xml
RUN sed -i 's/localhost:8081\/EidasNodeProxy\/ServiceMetadata/eidas-demo-cb:8081\/EidasNodeProxy\/ServiceMetadata/g' $config_path/proxy/eidas.xml

#metadata add new urls
#RUN sed '1{s/$/-;http:\/\/eidas-demo-ca:8080\/EidasNodeProxy\/ServiceMetadata;http:\/\/eidas-demo-cb:8081\/EidasNodeProxy\/ServiceMetadata/}' $config_path/connector/metadata/MetadataFetcher_Connector.properties
#RUN sed '18{s/$/-;http:\/\/eidas-demo-ca:8080\/EidasNodeConnector\/ConnectorMetadata;http:\/\/eidas-demo-cb:8081\/EidasNodeConnector\/ConnectorMetadata/}' $config_path//proxy/metadata/MetadataFetcher_Service.properties
COPY docker/config/MetadataFetcher_Connector.properties $config_path/connector/metadata/MetadataFetcher_Connector.properties
COPY docker/config/MetadataFetcher_Service.properties $config_path/proxy/metadata/MetadataFetcher_Service.properties

FROM tomcat:9.0-jre11-temurin-jammy

ENV TOMCAT_HOME /usr/local/tomcat

# change tomcat port
RUN sed -i 's/port="8080"/port="8081"/' ${TOMCAT_HOME}/conf/server.xml

# install bouncycastle
##  Add the Bouncy Castle provider jar to the $JAVA_HOME/jre/lib/ext directory
## Create a Bouncy Castle provider entry in the $JAVA_HOME/jre/lib/security/java.security file with correct number N: security.provider.N=org.bouncycastle.jce.provider.BouncyCastleProvider
RUN ls -la /opt/java/openjdk/conf/security/
COPY docker/config/java.security /opt/java/openjdk/conf/security/java.security
COPY docker/config/bcprov-jdk18on-1.78.jar /usr/local/lib/bcprov-jdk18on-1.78.jar

# copy eidas-config
RUN mkdir -p ${TOMCAT_HOME}/eidas-config/
COPY --from=builder /tmp/tomcat/ ${TOMCAT_HOME}/eidas-config/


# Copy setenv.sh to /usr/local/tomcat/bin/
COPY docker/config/setenv.sh ${TOMCAT_HOME}/bin/

# Add war files to webapps: /usr/local/tomcat/webapps
COPY --from=builder /data/TOMCAT/*.war ${TOMCAT_HOME}/webapps/

# eIDAS audit log folder
RUN mkdir -p ${TOMCAT_HOME}/eidas/logs

EXPOSE 8081
