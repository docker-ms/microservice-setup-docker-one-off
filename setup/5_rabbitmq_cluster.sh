#!/bin/bash

#################################################################################################################################################
# 5. Bring up RabbitMQ cluster in 'gate_services_stack' network.
#################################################################################################################################################

config=$(cat "./config.json")

machines=$(jq '.machines' <<< "$config")

swarm_master_hostname=$(jq -r '.[0].hostname' <<< "$machines")

consul_health_check_opts_ttl=$(jq -r '.consulHealthCheckOpts.ttl' <<< "$config")
consul_health_check_opts_timeout=$(jq -r '.consulHealthCheckOpts.timeout' <<< "$config")
consul_health_check_opts_interval=$(jq -r '.consulHealthCheckOpts.interval' <<< "$config")
consul_health_check_opts_deregister_after=$(jq -r '.consulHealthCheckOpts.deregisterAfter' <<< "$config")

#
## $1: auxiliary index.
## $2: rabbitmq node type.
## $3: target hostname.
#
function create_rabbitmq_server () {
  # Change 'docker-machine' env.
  eval "$(docker-machine env $swarm_master_hostname)"

  docker service create \
    --mode replicated \
    --replicas 1 \
    --network gate_services_stack \
    --name "rabbitmq_server_$1" \
    --hostname "rabbitmq_server_$1" \
    --env RABBITMQ_HIPE_COMPILE=1 \
    \
    --env RABBITMQ_ERLANG_COOKIE=e705fb595df640baa6df37c0f967bd11 \
    \
    --env RABBITMQ_DEFAULT_USER=leonard \
    --env RABBITMQ_DEFAULT_PASS=1234567890 \
    \
    --env RABBITMQ_NODE_TYPE="$2" \
    \
    --env SERVICE_4369_IGNORE=true \
    --env SERVICE_25672_IGNORE=true \
    --env SERVICE_5671_IGNORE=true \
    --env SERVICE_15671_IGNORE=true \
    \
    --env SERVICE_5671_NAME="rabbitmq_server_$1:5671@$3:$((65100+$1))" \
    --env SERVICE_15671_NAME="rabbitmq_mui_$1@$3:$((65199-$1))" \
    \
    --env SERVICE_5672_NAME="rabbitmq_server_$1:5672@$3:$((65200+$1))" \
    --env SERVICE_15672_NAME="rabbitmq_mui_$1@$3:$((65299-$1))" \
    \
    --env SERVICE_5672_CHECK_TTL="$consul_health_check_opts_ttl" \
    --env SERVICE_5672_CHECK_SCRIPT='nc -vz $SERVICE_IP $SERVICE_PORT; exit $(($? == 0 ? 0 : 500))' \
    --env SERVICE_5672_CHECK_TIMEOUT="$consul_health_check_opts_timeout" \
    --env SERVICE_5672_CHECK_INTERVAL="$consul_health_check_opts_interval" \
    --env SERVICE_5672_CHECK_DEREGISTER_AFTER="$consul_health_check_opts_deregister_after" \
    \
    --env SERVICE_15672_CHECK_TTL="$consul_health_check_opts_ttl" \
    --env SERVICE_15672_CHECK_HTTP=/ \
    --env SERVICE_15672_CHECK_TIMEOUT="$consul_health_check_opts_timeout" \
    --env SERVICE_15672_CHECK_INTERVAL="$consul_health_check_opts_interval" \
    --env SERVICE_15672_CHECK_DEREGISTER_AFTER="$consul_health_check_opts_deregister_after" \
    \
    --publish "mode=host,target=5671,published=$((65100+$1))" \
    --publish "mode=host,target=15671,published=$((65199-$1))" \
    --publish "mode=host,target=5672,published=$((65200+$1))" \
    --publish "mode=host,target=15672,published=$((65299-$1))" \
    \
    --constraint "node.hostname == $3" \
    --restart-condition any \
    rabbitmq:3.6.10-management-alpine

  # Reset 'docker-machine' env.
  eval "$(docker-machine env -u)"
}

rabbitmq_machines=$(jq -r 'map(select(.asRabbitMQServer != null and .asRabbitMQServer != false))' <<< "$machines")

for ((idx=0; idx<$(jq 'length' <<< "$rabbitmq_machines"); idx++))
do
  rabbitmq_node_type=$(jq -r ".[$idx].asRabbitMQServer.rabbitmqNodeType" <<< "$rabbitmq_machines")
  rabbitmq_machine_hostname=$(jq -r ".[$idx].hostname" <<< "$rabbitmq_machines")

  create_rabbitmq_server "$idx" "$rabbitmq_node_type" "$rabbitmq_machine_hostname"
done


