#!/bin/bash

#################################################################################################################################################
# 3. Bring up 'registrator' as docker global service in 'gate_services_stack' network.
#################################################################################################################################################

config=$(cat "./config.json")

swarm_master_hostname=$(jq -r '.machines[0].hostname' <<< "$config")

# Change 'docker-machine' env.
eval "$(docker-machine env $swarm_master_hostname)"

docker service create \
  --name registrator \
  --mode global \
  --network gate_services_stack \
  --mount type=bind,src=/var/run/docker.sock,dst=/tmp/docker.sock,readonly \
  --restart-condition any \
  gliderlabs/registrator:master \
  -cleanup \
  -deregister always \
  -internal \
  consul://consul_agent_client_0:65401

# Reset 'docker-machine' env.
eval "$(docker-machine env -u)"


