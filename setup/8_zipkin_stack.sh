#!/bin/bash

#################################################################################################################################################
# 8. Bring up openzipkin stack in 'gate_services_stack' network.
#
# Note: this step depends on the step '7_fluentd_stack' setup.
#################################################################################################################################################

config=$(cat "./config.json")

machines=$(jq '.machines' <<< "$config")

swarm_master_hostname=$(jq -r '.[0].hostname' <<< "$machines")

consul_health_check_opts_ttl=$(jq -r '.consulHealthCheckOpts.ttl' <<< "$config")
consul_health_check_opts_timeout=$(jq -r '.consulHealthCheckOpts.timeout' <<< "$config")
consul_health_check_opts_interval=$(jq -r '.consulHealthCheckOpts.interval' <<< "$config")
consul_health_check_opts_deregister_after=$(jq -r '.consulHealthCheckOpts.deregisterAfter' <<< "$config")

#
## $1: target physical machine hostname.
#
function create_zipkin_server () {
  # Change 'docker-machine' env.
  eval "$(docker-machine env $swarm_master_hostname)"

  docker service create \
    --mode replicated \
    --replicas 1 \
    --network gate_services_stack \
    --name zipkin_server_0 \
    --hostname zipkin_server_0 \
    \
    --env SERVICE_9410_IGNORE=true \
    --env SERVICE_9411_NAME="zipkin_server_0@$1:64800" \
    \
    --env STORAGE_TYPE=elasticsearch \
    --env ES_HOSTS=http://elasticsearch-coordinator-server-0:9200 \
    \
    --env SERVICE_9411_CHECK_TTL="$consul_health_check_opts_ttl" \
    --env SERVICE_9411_CHECK_HTTP=/ \
    --env SERVICE_9411_CHECK_TIMEOUT="$consul_health_check_opts_timeout" \
    --env SERVICE_9411_CHECK_INTERVAL="$consul_health_check_opts_interval" \
    --env SERVICE_9411_CHECK_DEREGISTER_AFTER="$consul_health_check_opts_deregister_after" \
    \
    --publish mode=host,target=9411,published=64800 \
    \
    --constraint "node.hostname == $1" \
    --restart-condition any \
    \
    openzipkin/zipkin:1.28.1

  # Reset 'docker-machine' env.
  eval "$(docker-machine env -u)"
}

zipkin_servers=$(jq -r 'map(select(.asZipkinServer == true))' <<< "$machines")
if [[ $(jq 'length' <<< "$zipkin_servers") != 1 ]]; then
  echo "ERROR: This script expects to have exact 1 zipkin server, if you'd like to change the zipkin setup, refine this script."
  return
else
  create_zipkin_server $(jq -r '.[0].hostname' <<< "$zipkin_servers")
fi


