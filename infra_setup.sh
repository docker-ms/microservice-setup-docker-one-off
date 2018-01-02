#!/bin/bash

#
## Note: Some of these steps need to be done orderly, so:
##   if you want to use `for loop` or parallelize it please pay enough attentions.
#

. ./setup/1_docker_engine_and_network_and_swarm_cluster.sh

. ./setup/2_supervisor_consul_cluster.sh

. ./setup/3_registrator.sh

. ./setup/4_registries.sh

. ./setup/5_rabbitmq_cluster.sh

. ./setup/6_email_server.sh


