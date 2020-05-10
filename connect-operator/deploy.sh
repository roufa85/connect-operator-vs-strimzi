#!/bin/bash

source ./env.sh

kubectl login ${OPENSHIFT_URL} -u ${OPENSHIFT_USR} -p ${OPENSHIFT_PSW}

kubectl new-project ${OPENSHIFT_NS} || true

#####################################################################################
#####################################################################################

kubectl apply -f strimzi/cluster-operator/00-service-account/

kubectl apply -f strimzi/cluster-operator/01-rbacs/

kubectl apply -f strimzi/cluster-operator/02-crds/

kubectl apply -f strimzi/cluster-operator/03-deployments/

kubectl rollout status deployment/strimzi-cluster-operator

kubectl apply -f strimzi/cluster-operator/04-crs/

sleep 40s;

# kubectl get sts/ephemeral-zookeeper --watch --request-timeout=30s

# kubectl get sts/ephemeral-kafka --watch --request-timeout=30s

#####################################################################################
#####################################################################################

kubectl apply -f strimzi/topic-operator/00-service-account/

kubectl apply -f strimzi/topic-operator/01-rbacs/

kubectl apply -f strimzi/topic-operator/02-crds/

kubectl apply -f strimzi/topic-operator/03-deployments/00-zoo-entrance.yaml

kubectl rollout status deployment/zoo-entrance

kubectl apply -f strimzi/topic-operator/03-deployments/01-ephemeral-topic-operator-deployment.yaml

kubectl rollout status deployment/ephemeral-topic-operator

#####################################################################################
#####################################################################################

kubectl apply -f strimzi/topic-operator/04-crs/

kubectl get kt

sleep 5s;
kubectl exec -it ephemeral-kafka-0 -c kafka -- bin/kafka-topics.sh --zookeeper localhost:2181 --list

kubectl exec -it ephemeral-kafka-0 -c kafka -- bin/kafka-topics.sh --zookeeper localhost:2181 --describe --topic test-topic

echo '{"tasks.max": "20", "key.ignore": "false"}' | kubectl exec -i -c kafka ephemeral-kafka-0 -- /opt/kafka/bin/kafka-console-producer.sh \
                    --broker-list ephemeral-kafka-bootstrap:9092 \
                    --topic test-topic

kubectl exec -i -c kafka ephemeral-kafka-0 -- /opt/kafka/bin/kafka-console-consumer.sh \
    --bootstrap-server ephemeral-kafka-bootstrap:9092 \
    --topic test-topic --from-beginning

#####################################################################################
#####################################################################################

kubectl apply -f ../elastic/es-service-account.yaml
kubectl adm policy add-scc-to-user privileged -n ${OPENSHIFT_NS} -z elasticsearch
kubectl apply -f ../elastic/elasticsearch-kibana.yaml

kubectl rollout status deployment/kibana
kubectl port-forward service/kibana 5601 &
chromium-browser http://127.0.0.1:5601

#####################################################################################
#####################################################################################

kubectl apply -f deploy/service_account.yaml
kubectl apply -f deploy/crds/
kubectl apply -f deploy/role.yaml
kubectl apply -f deploy/role_binding.yaml
kubectl apply -f deploy/cluster_role.yaml
kubectl apply -f deploy/cluster_role_binding.yaml
kubectl apply -f deploy/operator.yaml
kubectl rollout status deployment/kubernetes-kafka-connect-operator

#####################################################################################
#####################################################################################

kubectl apply -f examples/v1alpha1/experiment-ssp.yaml
#kubectl logs -f deployment/experiment-ssp
#kubectl rollout status deployment/experiment-ssp

echo '{"tasks.max": "10", "key.ignore": "false"}' | kubectl exec -i -c kafka ephemeral-kafka-0 -- /opt/kafka/bin/kafka-console-producer.sh \
                    --broker-list ephemeral-kafka-bootstrap:9092 \
                    --topic test-topic

# curl -k -XDELETE http://lkubectlalhost:8083/connectors/connector-elastic/

# curl -k -XPUT http://lkubectlalhost:8083/connectors/connector-elastic/config/ -H 'Content-Type: application/json' -H 'Accept: application/json' -d '{
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

kubectl get --raw "/apis/custom.metrics.k8s.io/"
kubectl get --raw "/apis/kafkaconnect.operator.io/v1alpha1/"

kubectl get --raw "/apis/custom.metrics.k8s.io/v1beta2"
# Error from server (ServiceUnavailable): the server is currently unable to handle the request

kubectl apply -f examples/v1alpha1/kafkaconnectautoscaler.yaml

kubectl describe  KafkaConnectAutoScaler/example-kafkaconnectautoscaler

#   Type     Reason                        Age   From                     Message
#   ----     ------                        ----  ----                     -------
#   Warning  FailedGetObjectMetric         37s   kafkaconnect-autoscaler  unable to get metric connector-elastic-lag: KafkaConnect on test-operator experiment-ssp/unable to fetch metrics from custom metrics API: the server is currently unable to handle the request (get kafkaconnects.kafkaconnect.operator.io.custom.metrics.k8s.io experiment-ssp)
#   Warning  FailedComputeMetricsReplicas  37s   kafkaconnect-autoscaler  invalid metrics (1 invalid out of 1), first error is: failed to get object metric value: unable to get metric connector-elastic-lag: KafkaConnect on test-operator experiment-ssp/unable to fetch metrics from custom metrics API: the server is currently unable to handle the request (get kafkaconnects.kafkaconnect.operator.io.custom.metrics.k8s.io experiment-ssp)

#####################################################################################
#####################################################################################

kubectl delete -Rf strimzi/
kubectl delete -Rf deploy/
kubectl delete -Rf ../elastic/
#kubectl delete project ${OPENSHIFT_NS}