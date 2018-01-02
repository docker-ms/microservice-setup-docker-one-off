#!/bin/bash

#################################################################################################################################################
# 1. Set up docker engine and construct docker swarm cluster.
#################################################################################################################################################

config=$(cat "./config.json")

remote_provisioner_user=$(jq -r '.remoteProvisioner.user' <<< "$config")
remote_provisioner_user_rsa_key_path=$(jq -r '.remoteProvisioner.path2RSAKey' <<< "$config")

machines=$(jq '.machines' <<< "$config")

has_done_swarm_init=false
swarm_master_addr=null
swarm_manager_token=null
swarm_worker_token=null

for ((idx=0; idx<$(jq length <<< "$machines"); idx++))
do
  machine_hostname=$(jq -r ".[$idx].hostname" <<< "$machines")
  machine_ip=$(jq -r ".[$idx].ip" <<< "$machines")

  docker-machine rm -f "$machine_hostname" &> /dev/null

  #
  ## Install docker engine.
  #
  docker-machine create \
    --driver generic \
    --generic-ip-address "$machine_ip" \
    --generic-ssh-user "$remote_provisioner_user" \
    --generic-ssh-key "$remote_provisioner_user_rsa_key_path" \
    --engine-opt dns=8.8.8.8 \
    --engine-insecure-registry $(jq -r '.registries.dev.hostname + ":" + (.registries.dev.port | tostring)' <<< "$config") \
    --engine-label instanceType=$(jq -r ".[$idx].labels.instanceType" <<< "$machines") \
    "$machine_hostname"

  # Change 'docker-machine' env.
  eval "$(docker-machine env $machine_hostname)"

  if [[ "$has_done_swarm_init" == false ]]; then
    if [[ $(jq ".[$idx].asSwarmManager" <<< "$machines") == true ]]; then
      # Force node to leave the old swarm cluster if there is one.
      docker swarm leave -f 2> /dev/null

      # Init new swarm cluster.
      docker swarm init \
        --advertise-addr "$machine_ip" \
        --cert-expiry 2160h0m0s \
        --dispatcher-heartbeat 5s \
        --listen-addr 0.0.0.0:2377 \
        --max-snapshots 0 \
        --snapshot-interval 10000 \
        --task-history-limit 5

      #
      ## Query swarm master address and tokens.
      #
      swarm_master_addr=$(docker info --format "{{.Swarm.NodeAddr}}")
      swarm_manager_token=$(docker swarm join-token -q manager)
      swarm_worker_token=$(docker swarm join-token -q worker)

      # #
      # ## Remove and recreate ingress network to get around of the issue:
      # ##   https://github.com/moby/moby/issues/33626
      # #
      # yes y | docker network rm ingress

      # docker network create \
      #   --driver overlay \
      #   --subnet $(jq -r '.subnets.ingress' <<< "$config") \
      #   --ingress \
      #   ingress

      yes y | docker network rm management &> /dev/null

      # Create 'management' network.
      docker network create \
        --driver overlay \
        --attachable=true \
        --subnet $(jq -r '.subnets.management' <<< "$config") \
        management

      yes y | docker network rm gate_services_stack &> /dev/null

      # Create 'gateServicesStack' network.
      docker network create \
        --driver overlay \
        --attachable=true \
        --subnet $(jq -r '.subnets.gateServicesStack' <<< "$config") \
        gate_services_stack

      has_done_swarm_init=true
    else
      echo "Error: first node in the 'machines' section must be set as manager."
      return
    fi
  else
    # Force node to leave the old swarm cluster if there is one.
    docker swarm leave -f 2> /dev/null

    if [[ $(jq ".[$idx].asSwarmManager" <<< "$machines") == true ]]; then
      # Join this node as manager.
      docker swarm join \
        --token "$swarm_manager_token" \
        "$swarm_master_addr"
    else
      # Join this node as worker.
      docker swarm join \
      --token "$swarm_worker_token" \
      "$swarm_master_addr"
    fi
  fi

  # Reset 'docker-machine' env.
  eval "$(docker-machine env -u)"
done


