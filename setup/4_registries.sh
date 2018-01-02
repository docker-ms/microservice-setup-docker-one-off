#!/bin/bash

#################################################################################################################################################
# 4. Bring up 'dev', 'stg', 'prd_0' and 'prd_1' registries in 'gate_services_stack' network.
#################################################################################################################################################

config=$(cat "./config.json")

machines=$(jq '.machines' <<< "$config")

swarm_master_hostname=$(jq -r '.[0].hostname' <<< "$machines")

remote_provisioner_user_home_dir=$(jq -r '.remoteProvisioner.homeDir' <<< "$config")

consul_health_check_opts_ttl=$(jq -r '.consulHealthCheckOpts.ttl' <<< "$config")
consul_health_check_opts_timeout=$(jq -r '.consulHealthCheckOpts.timeout' <<< "$config")
consul_health_check_opts_interval=$(jq -r '.consulHealthCheckOpts.interval' <<< "$config")
consul_health_check_opts_deregister_after=$(jq -r '.consulHealthCheckOpts.deregisterAfter' <<< "$config")

#
## $1: target hostname.
#
function scp_tls_certs () {
  if [[ "$1" == *".sgdev.vcube.com" ]]; then
    dst="${remote_provisioner_user_home_dir}docker_setup_tls_$1"

    # Always try to remove the destination directory if it was already there, for getting aound of some funky problems.
    docker-machine ssh "$2" sudo rm -rf "$dst"

    docker-machine scp -r \
      ./remote_conf/docker_setup_tls/docker_setup_*.sgdev.vcube.com \
      "$1:$dst"
  fi
}

#
## $1: 'dev', 'stg' or 'prd'.
## $2: target hostname.
#
function scp_registry_auth_conf () {
  dst="${remote_provisioner_user_home_dir}docker_setup_registry_$1"

  # Always try to remove the destination directory if it was already there, for getting aound of some funky problems.
  docker-machine ssh "$2" sudo rm -rf "$dst"

  docker-machine scp -r \
    "./remote_conf/docker_setup_registry_$1" \
    "$2:$dst"
}

#
## $1: 'dev', 'stg' or 'prd'.
## $2: target hostname.
## $3: target port.
#
function create_registry_service () {
  # Change 'docker-machine' env.
  eval "$(docker-machine env $swarm_master_hostname)"

  docker service create \
    --mode replicated \
    --replicas 1 \
    --network gate_services_stack \
    --name "registry_$1" \
    --mount "type=bind,src=${remote_provisioner_user_home_dir}docker_setup_tls_$2/server,dst=/certs" \
    --mount "type=bind,src=${remote_provisioner_user_home_dir}docker_setup_registry_$1/auth,dst=/auth" \
    \
    --env REGISTRY_HTTP_TLS_CERTIFICATE=/certs/server_cert.pem \
    --env REGISTRY_HTTP_TLS_KEY=/certs/server_cert_private_key.pem \
    \
    --env REGISTRY_AUTH=htpasswd \
    --env REGISTRY_AUTH_HTPASSWD_PATH=/auth/htpasswd \
    --env REGISTRY_AUTH_HTPASSWD_REALM="Registry Realm" \
    --env REGISTRY_HTTP_SECRET=1ea81823c38c4fe0b3267d61b8b029c6 \
    \
    --env REGISTRY_STORAGE_DELETE_ENABLED=true \
    \
    --env SERVICE_TAGS="$1,$2,$3" \
    \
    --env SERVICE_CHECK_TTL="$consul_health_check_opts_ttl" \
    --env SERVICE_CHECK_TIMEOUT="$consul_health_check_opts_timeout" \
    --env SERVICE_CHECK_INTERVAL="$consul_health_check_opts_interval" \
    --env SERVICE_CHECK_SCRIPT='nc -vz $SERVICE_IP $SERVICE_PORT; exit $(($? == 0 ? 0 : 500))' \
    --env SERVICE_CHECK_DEREGISTER_AFTER="$consul_health_check_opts_deregister_after" \
    \
    --publish "mode=host,target=5000,published=$3" \
    --constraint "node.hostname == $2" \
    --restart-condition any \
    registry:2.6.1

  # Reset 'docker-machine' env.
  eval "$(docker-machine env -u)"
}

#
## Set up 'dev' registry.
#
dev_registry_hostname=$(jq -r '.registries.dev.hostname' <<< "$config")
dev_registry_port=$(jq -r '.registries.dev.port' <<< "$config")
if [[ -n "$dev_registry_hostname" ]]; then
  scp_tls_certs "$dev_registry_hostname"
  scp_registry_auth_conf "dev" "$dev_registry_hostname"
  create_registry_service "dev" "$dev_registry_hostname" "$dev_registry_port"
fi

#
## Set up 'stg' registry.
#
stg_registry_hostname=$(jq -r '.registries.stg.hostname' <<< "$config")
stg_registry_port=$(jq -r '.registries.stg.port' <<< "$config")
if [[ -n "$stg_registry_hostname" ]]; then
  scp_tls_certs "$stg_registry_hostname"
  scp_registry_auth_conf "stg" "$stg_registry_hostname"
  create_registry_service "stg" "$stg_registry_hostname" "$stg_registry_port"
fi

#
## Set up 'prd_0' registry.
#
prd_registry_0_hostname=$(jq -r '.registries.prd."0".hostname' <<< "$config")
prd_registry_0_port=$(jq -r '.registries.prd."0".port' <<< "$config")
if [[ -n "$prd_registry_0_hostname" ]]; then
  scp_tls_certs "$prd_registry_0_hostname"
  scp_registry_auth_conf "prd" "$prd_registry_0_hostname"
  create_registry_service "prd" "$prd_registry_0_hostname" "$prd_registry_0_port"
fi

#
## Set up 'prd_1' registry.
#
prd_registry_1_hostname=$(jq -r '.registries.prd."1".hostname' <<< "$config")
prd_registry_1_port=$(jq -r '.registries.prd."1".port' <<< "$config")
if [[ -n "$prd_registry_1_hostname" ]]; then
  scp_tls_certs "$prd_registry_1_hostname"
  scp_registry_auth_conf "prd" "$prd_registry_1_hostname"
  create_registry_service "prd" "$prd_registry_1_hostname" "$prd_registry_1_port"
fi


