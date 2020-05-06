#!/bin/bash

source ./env.sh

oc login ${OPENSHIFT_URL} -u ${OPENSHIFT_USR} -p ${OPENSHIFT_PSW}

oc new-project ${OPENSHIFT_NS} || true

#####################################################################################
#####################################################################################

oc apply -f strimzi/cluster-operator/00-service-account/

oc apply -f strimzi/cluster-operator/01-rbacs/

oc apply -f strimzi/cluster-operator/02-crds/

oc apply -f strimzi/cluster-operator/03-deployments/

oc rollout status deployment/strimzi-cluster-operator

oc apply -f strimzi/cluster-operator/04-crs/

sleep 40s;

# oc get sts/ephemeral-zookeeper --watch --request-timeout=30s

# oc get sts/ephemeral-kafka --watch --request-timeout=30s

#####################################################################################
#####################################################################################

oc apply -f strimzi/topic-operator/00-service-account/

oc apply -f strimzi/topic-operator/01-rbacs/

oc apply -f strimzi/topic-operator/02-crds/

oc apply -f strimzi/topic-operator/03-deployments/00-zoo-entrance.yaml

oc rollout status deployment/zoo-entrance

oc apply -f strimzi/topic-operator/03-deployments/01-ephemeral-topic-operator-deployment.yaml

oc rollout status deployment/ephemeral-topic-operator

#####################################################################################
#####################################################################################

oc apply -f strimzi/topic-operator/04-crs/

oc get kt

sleep 5s;
oc exec -it ephemeral-kafka-0 -c kafka -- bin/kafka-topics.sh --zookeeper localhost:2181 --list

oc exec -it ephemeral-kafka-0 -c kafka -- bin/kafka-topics.sh --zookeeper localhost:2181 --describe --topic test-topic

echo '{"tasks.max": "20", "key.ignore": "false"}' | oc exec -i -c kafka ephemeral-kafka-0 -- /opt/kafka/bin/kafka-console-producer.sh \
                    --broker-list ephemeral-kafka-bootstrap:9092 \
                    --topic test-topic

oc exec -i -c kafka ephemeral-kafka-0 -- /opt/kafka/bin/kafka-console-consumer.sh \
    --bootstrap-server ephemeral-kafka-bootstrap:9092 \
    --topic test-topic --from-beginning

#####################################################################################
#####################################################################################

oc apply -f ../elastic/es-service-account.yaml
oc adm policy add-scc-to-user privileged -n ${OPENSHIFT_NS} -z elasticsearch
oc apply -f ../elastic/elasticsearch-kibana.yaml

oc rollout status deployment/kibana
oc port-forward service/kibana 5601 &
chromium-browser http://127.0.0.1:5601

#####################################################################################
#####################################################################################

oc apply -f deploy/service_account.yaml
oc apply -f deploy/crds/
oc apply -f deploy/role.yaml
oc apply -f deploy/role_binding.yaml
oc apply -f deploy/cluster_role.yaml
oc apply -f deploy/cluster_role_binding.yaml
oc apply -f deploy/operator.yaml
oc rollout status deployment/kubernetes-kafka-connect-operator

#####################################################################################
#####################################################################################

oc apply -f examples/v1alpha1/experiment-ssp.yaml
#oc logs -f deployment/experiment-ssp
#oc rollout status deployment/experiment-ssp

echo '{"tasks.max": "10", "key.ignore": "false"}' | oc exec -i -c kafka ephemeral-kafka-0 -- /opt/kafka/bin/kafka-console-producer.sh \
                    --broker-list ephemeral-kafka-bootstrap:9092 \
                    --topic test-topic

# curl -k -XDELETE http://localhost:8083/connectors/connector-elastic/

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

oc get --raw "/apis/custom.metrics.k8s.io/"
oc get --raw "/apis/kafkaconnect.operator.io/v1alpha1/"

oc get --raw "/apis/custom.metrics.k8s.io/v1beta2"
# Error from server (ServiceUnavailable): the server is currently unable to handle the request

oc apply -f examples/v1alpha1/kafkaconnectautoscaler.yaml

oc describe  KafkaConnectAutoScaler/example-kafkaconnectautoscaler

#   Type     Reason                        Age   From                     Message
#   ----     ------                        ----  ----                     -------
#   Warning  FailedGetObjectMetric         37s   kafkaconnect-autoscaler  unable to get metric connector-elastic-lag: KafkaConnect on test-operator experiment-ssp/unable to fetch metrics from custom metrics API: the server is currently unable to handle the request (get kafkaconnects.kafkaconnect.operator.io.custom.metrics.k8s.io experiment-ssp)
#   Warning  FailedComputeMetricsReplicas  37s   kafkaconnect-autoscaler  invalid metrics (1 invalid out of 1), first error is: failed to get object metric value: unable to get metric connector-elastic-lag: KafkaConnect on test-operator experiment-ssp/unable to fetch metrics from custom metrics API: the server is currently unable to handle the request (get kafkaconnects.kafkaconnect.operator.io.custom.metrics.k8s.io experiment-ssp)

#####################################################################################
#####################################################################################

oc delete -Rf strimzi/
oc delete -Rf deploy/
oc delete -Rf ../elastic/
#oc delete project ${OPENSHIFT_NS}