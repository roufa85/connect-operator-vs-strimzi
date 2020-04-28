#!/bin/bash

source ./env.sh

oc login ${OPENSHIFT_URL} -u ${OPENSHIFT_USR} -p ${OPENSHIFT_PSW} --insecure-skip-tls-verify=true

oc new-project ${OPENSHIFT_NS}

#####################################################################################
#####################################################################################

oc apply -f 00-service-account/

oc apply -f 01-rbacs/

oc apply -f 02-crds/

oc apply -f 03-deployments/

oc rollout status deployment/strimzi-cluster-operator

oc apply -f 04-crs/00-ephemeral-kafka-cr.yaml

sleep 10s;

oc get sts/ephemeral-zookeeper --watch --request-timeout=30s

oc get sts/ephemeral-kafka --watch --request-timeout=30s

oc apply -f 04-crs/01-ephemeral-topics-cr.yaml

oc get kt
sleep 5s;

oc exec -it ephemeral-kafka-0 -c kafka -- bin/kafka-topics.sh --zookeeper localhost:2181 --describe --topic test-topic

oc apply -f 04-crs/02-ephemeral-connect-cr.yaml

oc rollout status deployment/ephemeral-connect

oc apply -f 04-crs/03-ephemeral-file-connector-cr.yaml

oc exec -i -c kafka ephemeral-kafka-0 -- curl -X GET http://ephemeral-connect-api:8083/connectors/
sleep 15s;

oc apply -f 04-crs/04-ephemeral-es-connector-cr.yaml

oc exec -i -c kafka ephemeral-kafka-0 -- curl -X GET http://ephemeral-connect-api:8083/connectors/ephemeral-source-connector/status/

oc exec -i -c kafka ephemeral-kafka-0 -- curl -X GET http://ephemeral-connect-api:8083/connectors/ephemeral-es-connector/status/

oc exec -i -c kafka ephemeral-kafka-0 -- /opt/kafka/bin/kafka-console-consumer.sh \
    --bootstrap-server ephemeral-kafka-bootstrap:9092 \
    --topic test-topic --from-beginning

# oc delete -Rf ./

# oc delete project ${OPENSHIFT_NS}

# oc logout


# curl -k -XPUT http://localhost:8083/connectors/connector-elastic/config/ -H 'Content-Type: application/json' -H 'Accept: application/json' -d '{
#     "connector.class": "io.confluent.connect.elasticsearch.ElasticsearchSinkConnector",
#     "tasks.max": "2",
#     "topics": "test-topic",
#     "key.ignore": "true",
#     "connection.url": "http://elastic-svc:9200",
#     "type.name": "index",
#     "name": "connector-elastic",
#     "schema.ignore": "true",
#     "value.converter": "org.apache.kafka.connect.json.JsonConverter",
#     "value.converter.schemas.enable": "false"
# }'