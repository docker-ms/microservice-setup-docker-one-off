#!/bin/bash

#################################################################################################################################################
# 2. Bring up infrastructure supervisor: consul cluster in 'gate_services_stack' network.
#
# Current the design is: 3 consul server agents, and 3 consul client agents, should have no any necessities to run bigger scale, if we need to
#   change the design, refine this part of script.
#################################################################################################################################################

config=$(cat "./config.json")

machines=$(jq '.machines' <<< "$config")

swarm_master_hostname=$(jq -r '.[0].hostname' <<< "$machines")

consul_server_config=$(jq -r -s '.[0] * .[1]' "./stacks/gate/config/consul/shared.json" "./stacks/gate/config/consul/server.json")
consul_client_config=$(jq -r -s '.[0] * .[1]' "./stacks/gate/config/consul/shared.json" "./stacks/gate/config/consul/client.json")

#
## Used by `envsubst`.
#
export CONSUL_LOCAL_CONFIG_SERVER="'$consul_server_config'"
export CONSUL_LOCAL_CONFIG_CLIENT="'$consul_client_config'"

consul_server_agents=$(jq -r 'map(select(.asConsulServerAgent == true))' <<< "$machines")
if [[ $(jq 'length' <<< "$consul_server_agents") != 3 ]]; then
  echo "This script expects to have exact 3 consul server agents, if you'd like to change the consul cluster setup, please refine this script."
  return
else
  export CONSUL_AGENT_SERVER_0_HOSTNAME=$(jq -r '.[0].hostname' <<< "$consul_server_agents")
  export CONSUL_AGENT_SERVER_1_HOSTNAME=$(jq -r '.[1].hostname' <<< "$consul_server_agents")
  export CONSUL_AGENT_SERVER_2_HOSTNAME=$(jq -r '.[2].hostname' <<< "$consul_server_agents")
fi

consul_client_agents=$(jq -r 'map(select(.asConsulClientAgent == true))' <<< "$machines")
if [[ $(jq 'length' <<< "$consul_client_agents") != 3 ]]; then
  echo "This script expects to have exact 3 consul client agents, if you'd like to change the consul cluster setup, please refine this script."
  return
else
  export CONSUL_AGENT_CLIENT_0_HOSTNAME=$(jq -r '.[0].hostname' <<< "$consul_client_agents")
  export CONSUL_AGENT_CLIENT_1_HOSTNAME=$(jq -r '.[1].hostname' <<< "$consul_client_agents")
  export CONSUL_AGENT_CLIENT_2_HOSTNAME=$(jq -r '.[2].hostname' <<< "$consul_client_agents")
fi

envsubst < "./stacks/gate/docker-compose.consul.tpl.yml" > "./stacks/gate/docker-compose.yml"

# Change 'docker-machine' env.
eval "$(docker-machine env $swarm_master_hostname)"

docker stack deploy \
  --compose-file ./stacks/gate/docker-compose.yml \
  gate_services_stack_consul

# Clean `envsubst` generated file './stacks/gate/docker-compose.yml'.
rm ./stacks/gate/docker-compose.yml

# Reset 'docker-machine' env.
eval "$(docker-machine env -u)"


