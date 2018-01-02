#!/bin/bash

#################################################################################################################################################
# 6. Bring up email server in 'gate_services_stack' network.
#################################################################################################################################################

config=$(cat "./config.json")

remote_provisioner_user_home_dir=$(jq -r '.remoteProvisioner.homeDir' <<< "$config")

machines=$(jq '.machines' <<< "$config")

swarm_master_hostname=$(jq -r '.[0].hostname' <<< "$machines")

consul_health_check_opts_ttl=$(jq -r '.consulHealthCheckOpts.ttl' <<< "$config")
consul_health_check_opts_timeout=$(jq -r '.consulHealthCheckOpts.timeout' <<< "$config")
consul_health_check_opts_interval=$(jq -r '.consulHealthCheckOpts.interval' <<< "$config")
consul_health_check_opts_deregister_after=$(jq -r '.consulHealthCheckOpts.deregisterAfter' <<< "$config")

#
## $1: target domain name.
## $2: target hostname.
#
function scp_email_server_conf () {
  if [[ "$1" == "microservices.vcube.sg" ]]; then
    dst="${remote_provisioner_user_home_dir}docker_setup_email_server_microservices.vcube.sg"

    # Always try to remove the destination directory if it was already there, for getting aound of some funky problems.
    docker-machine ssh "$2" sudo rm -rf "$dst"

    docker-machine scp -r \
      ./remote_conf/docker_setup_email_server_microservices.vcube.sg \
      "$2:$dst"
  fi
}

#
## $1: auxiliary index.
## $2: target hostname.
## $3: target domain name.
## $4: user_0:pwd_0
#
function create_email_server () {
  # Change 'docker-machine' env.
  eval "$(docker-machine env $swarm_master_hostname)"

  #
  ## Note: publishing port here is only for testing purpose, for production we definitely should remove the port publishing.
  #
  docker service create \
    --mode replicated \
    --replicas 1 \
    --network gate_services_stack \
    --name "email_server_$1" \
    --hostname "email_server_$1" \
    --env DKIM_CANONICALIZATION=simple \
    \
    --env SERVICE_NAME="email_server_$1" \
    --env SERVICE_TAGS="$2,$((65000+$1))" \
    \
    --env SERVICE_CHECK_TTL="$consul_health_check_opts_ttl" \
    --env SERVICE_CHECK_TIMEOUT="$consul_health_check_opts_timeout" \
    --env SERVICE_CHECK_INTERVAL="$consul_health_check_opts_interval" \
    --env SERVICE_CHECK_SCRIPT='nc -vz $SERVICE_IP $SERVICE_PORT; exit $(($? == 0 ? 0 : 500))' \
    --env SERVICE_CHECK_DEREGISTER_AFTER="$consul_health_check_opts_deregister_after" \
    \
    --mount "type=bind,src=${remote_provisioner_user_home_dir}docker_setup_email_server_$3/dkim/,dst=/etc/postfix/dkim/" \
    --publish "mode=host,target=25,published=$((65000+$1))" \
    --constraint "node.hostname == $2" \
    --restart-condition any \
    marvambass/versatile-postfix \
    "$3" \
    "$4"

  # Reset 'docker-machine' env.
  eval "$(docker-machine env -u)"
}

email_machines=$(jq -r 'map(select(.asEmailServer != null and .asEmailServer != false))' <<< "$machines")

for ((idx=0; idx<$(jq -r 'length' <<< "$email_machines"); idx++))
do
  email_machine_hostname=$(jq -r ".[$idx].hostname" <<< "$email_machines")
  email_machine_domain_name=$(jq -r ".[$idx].asEmailServer.domainName" <<< "$email_machines")
  email_server_user_0_credential=$(jq -r ".[$idx].asEmailServer.users | .[0]" <<< "$email_machines")

  scp_email_server_conf "$email_machine_domain_name" "$email_machine_hostname"
  create_email_server "$idx" "$email_machine_hostname" "$email_machine_domain_name" "$email_server_user_0_credential"
done


