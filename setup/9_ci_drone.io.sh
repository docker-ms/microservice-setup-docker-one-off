#!/bin/bash

#################################################################################################################################################
# 8. Bring up the CI drone.io stack in 'gate_services_stack' network.
#################################################################################################################################################

config=$(cat "./config.json")

machines=$(jq '.machines' <<< "$config")

swarm_master_hostname=$(jq -r '.[0].hostname' <<< "$machines")

remote_provisioner_user_home_dir=$(jq -r '.remoteProvisioner.homeDir' <<< "$config")

consul_health_check_opts_ttl=$(jq -r '.consulHealthCheckOpts.ttl' <<< "$config")
consul_health_check_opts_timeout=$(jq -r '.consulHealthCheckOpts.timeout' <<< "$config")
consul_health_check_opts_interval=$(jq -r '.consulHealthCheckOpts.interval' <<< "$config")
consul_health_check_opts_deregister_after=$(jq -r '.consulHealthCheckOpts.deregisterAfter' <<< "$config")

drone_io_servers=$(jq -r 'map(select(.asCIDroneIOServer == true))' <<< "$machines")
if [[ $(jq 'length' <<< "$drone_io_servers") != 1 ]]; then
  echo "This script expects to have exact 1 drone io server, if you'd like to change the setup, refine this script accordingly."
  return
else
  export DRONE_HOST=$(jq -r '.[0].hostname' <<< "$drone_io_servers")
fi

# drone force to use external data volume.
export DRONE_SQLITE_DATA_PATH="${remote_provisioner_user_home_dir}docker_volume_drone_sqlite_data"
docker-machine ssh "$DRONE_HOST" mkdir -p "$DRONE_SQLITE_DATA_PATH"

envsubst < "./stacks/gate/docker-compose.ci_drone_io.tpl.yml" > "./stacks/gate/docker-compose.yml"

# Change 'docker-machine' env.
eval "$(docker-machine env $swarm_master_hostname)"

docker stack deploy \
  --with-registry-auth=true \
  --compose-file ./stacks/gate/docker-compose.yml \
  gate_services_stack_drone_io

# Clean `envsubst` generated file './stacks/gate/docker-compose.yml'.
rm ./stacks/gate/docker-compose.yml

# Reset 'docker-machine' env.
eval "$(docker-machine env -u)"


