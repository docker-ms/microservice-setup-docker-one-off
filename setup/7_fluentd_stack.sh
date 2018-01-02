#!/bin/bash

#################################################################################################################################################
# 7. Bring up fluentd stack in 'gate_services_stack' network.
#################################################################################################################################################

config=$(cat "./config.json")

machines=$(jq '.machines' <<< "$config")

dev_registry_hostname=$(jq -r '.registries.dev.hostname' <<< "$config")
dev_registry_port=$(jq -r '.registries.dev.port' <<< "$config")
default_registry="${dev_registry_hostname}:${dev_registry_port}"
export REGISTRY="$default_registry"

remote_provisioner_user_home_dir=$(jq -r '.remoteProvisioner.homeDir' <<< "$config")

swarm_master_hostname=$(jq -r '.[0].hostname' <<< "$machines")

#
## $1: target hostname.
#
function scp_elasticsearch_config () {
  dst="${remote_provisioner_user_home_dir}docker_setup_elasticsearch"

  # Always try to remove the destination directory if it was already there, for getting aound of some funky problems.
  docker-machine ssh "$1" sudo rm -rf "$dst"

  docker-machine scp -r \
    ./remote_conf/elasticsearch \
    "$1:$dst"
}

#
## $1: target hostname.
#
function scp_fluentd_config () {
  dst="${remote_provisioner_user_home_dir}docker_setup_fluentd"

  # Always try to remove the destination directory if it was already there, for getting aound of some funky problems.
  docker-machine ssh "$1" sudo rm -rf "$dst"

  docker-machine scp -r \
    ./remote_conf/fluentd \
    "$1:$dst"
}

elasticsearch_servers=$(jq -r 'map(select(.asElasticsearchServer == true))' <<< "$machines")
if [[ $(jq 'length' <<< "$elasticsearch_servers") != 3 ]]; then
  echo "This script expects to have exact 3 elasticsearch servers, if you'd like to change the elasticsearch cluster setup, refine this script."
  return
else
  export REMOTE_PROVISIONER_USER_HOME_DIR="$remote_provisioner_user_home_dir"

  export ELASTICSEARCH_SERVER_0_HOSTNAME=$(jq -r '.[0].hostname' <<< "$elasticsearch_servers")
  export ELASTICSEARCH_SERVER_1_HOSTNAME=$(jq -r '.[1].hostname' <<< "$elasticsearch_servers")
  export ELASTICSEARCH_SERVER_2_HOSTNAME=$(jq -r '.[2].hostname' <<< "$elasticsearch_servers")

  scp_elasticsearch_config "$ELASTICSEARCH_SERVER_0_HOSTNAME"
  scp_elasticsearch_config "$ELASTICSEARCH_SERVER_1_HOSTNAME"
  scp_elasticsearch_config "$ELASTICSEARCH_SERVER_2_HOSTNAME"
fi

elasticsearch_coordinator_servers=$(jq -r 'map(select(.asElasticsearchCoordinatorServer == true))' <<< "$machines")
if [[ $(jq 'length' <<< "$elasticsearch_coordinator_servers") != 1 ]]; then
  echo "This script expects to have exact 1 elasticsearch coordinator server, if you'd like to change the setup, refine this script."
  return
else
  export ELASTICSEARCH_COORDINATOR_SERVER_0_CORRD_PHY_MACHINE_HOSTNAME=$(jq -r '.[0].hostname' <<< "$elasticsearch_coordinator_servers")
fi

fluentd_servers=$(jq -r 'map(select(.asFluentdServer == true))' <<< "$machines")
if [[ $(jq 'length' <<< "$fluentd_servers") != 1 ]]; then
  echo "This script expects to have exact 1 fluentd server, if you'd like to change the fluentd setup, refine this script."
else
  export FLUENTD_SERVER_0_CORRD_PHY_MACHINE_HOSTNAME=$(jq -r '.[0].hostname' <<< "$fluentd_servers")
  export FLUENTD_SERVER_0_CORRD_PHY_MACHINE_IP=$(jq -r '.[0].ip' <<< "$fluentd_servers")

  scp_fluentd_config "$FLUENTD_SERVER_0_CORRD_PHY_MACHINE_HOSTNAME"
fi

grafana_servers=$(jq -r 'map(select(.asGrafanaServer == true))' <<< "$machines")
if [[ $(jq 'length' <<< "$grafana_servers") != 1 ]]; then
  echo "This script expects to have exact 1 grafana server, if you'd like to change the setup, refine this script."
  return
else
  export GRAFANA_SERVER_0_CORRD_PHY_MACHINE_HOSTNAME=$(jq -r '.[0].hostname' <<< "$grafana_servers")
fi

envsubst < "./stacks/gate/docker-compose.fluentd_stack.tpl.yml" > "./stacks/gate/docker-compose.yml"

# Change 'docker-machine' env.
eval "$(docker-machine env $swarm_master_hostname)"

docker stack deploy \
  --with-registry-auth=true \
  --compose-file ./stacks/gate/docker-compose.yml \
  gate_services_stack_fluentd

# Clean `envsubst` generated file './stacks/gate/docker-compose.yml'.
rm ./stacks/gate/docker-compose.yml

# Reset 'docker-machine' env.
eval "$(docker-machine env -u)"


