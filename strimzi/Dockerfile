FROM strimzi/kafka:0.16.2-kafka-2.4.0
USER root:root
RUN mkdir -p /opt/kafka/plugins/kafka-connect-elasticsearch

COPY ./kafka-connect-elasticsearch /opt/kafka/plugins/kafka-connect-elasticsearch

USER 1001