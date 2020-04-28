#!/bin/bash

docker login --username=raoufsalem
docker build . -t custom-connect:3
docker images
docker run -it --rm custom-connect:3
docker tag custom-connect:3 raoufsalem/kafka-connect:0.16.2-kafka-2.4.0-es-5.1.4
docker push raoufsalem/kafka-connect:0.16.2-kafka-2.4.0-es-5.1.4