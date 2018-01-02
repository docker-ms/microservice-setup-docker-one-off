#!/bin/bash

config=$(cat "./config.json")

dev_registry_hostname=$(jq -r '.registries.dev.hostname' <<< "$config")
dev_registry_port=$(jq -r '.registries.dev.port' <<< "$config")
default_registry="${dev_registry_hostname}:${dev_registry_port}"

swarm_master_hostname=$(jq -r '.machines[0].hostname' <<< "$config")

consul_health_check_opts_ttl=$(jq -r '.consulHealthCheckOpts.ttl' <<< "$config")
consul_health_check_opts_timeout=$(jq -r '.consulHealthCheckOpts.timeout' <<< "$config")
consul_health_check_opts_interval=$(jq -r '.consulHealthCheckOpts.interval' <<< "$config")
consul_health_check_opts_deregister_after=$(jq -r '.consulHealthCheckOpts.deregisterAfter' <<< "$config")

export CONSUL_HEALTH_CHECK_OPTS_TTL="$consul_health_check_opts_ttl"
export CONSUL_HEALTH_CHECK_OPTS_TIMEOUT="$consul_health_check_opts_timeout"
export CONSUL_HEALTH_CHECK_OPTS_INTERVAL="$consul_health_check_opts_interval"
export CONSUL_HEALTH_CHECK_OPTS_DEREGISTER_AFTER="$consul_health_check_opts_deregister_after"

#
## Reset in case getopts has been used previously in the shell.
#
OPTIND=1

while getopts "pr:t:" opt; do
  case "$opt" in
    p )
      export RUN_MODE='PROD'
      ;;
    r )
      export REGISTRY="$OPTARG"
      ;;
    t )
      export SERVICE_TAG_SUFFIX="$OPTARG"
      export SERVICE_TAG_SUFFIX_1=$(sed -e 's/:/-1:/g' <<< "$OPTARG")
      ;;
  esac
done

export REGISTRY="${REGISTRY:-$default_registry}"

DOLLAR='$' envsubst < "./stacks/gate/docker-compose.ms.tpl.yml" > "./stacks/gate/docker-compose.yml"

# Change 'docker-machine' env.
eval "$(docker-machine env $swarm_master_hostname)"

#
## Start our microservices stack.
#
docker stack deploy \
  --with-registry-auth=true \
  --compose-file ./stacks/gate/docker-compose.yml \
  gate_services_stack_ms

# Clean `envsubst` generated file './stacks/gate/docker-compose.yml'.
rm ./stacks/gate/docker-compose.yml

# Reset 'docker-machine' env.
eval "$(docker-machine env -u)"


