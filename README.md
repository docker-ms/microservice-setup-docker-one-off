## Notes

1. Install docker CE on your Mac from the stable channel: https://docs.docker.com/docker-for-mac/install/

2. Install `docker-machine` and `docker-compose` on your Mac.

    ```
    brew install docker-machine docker-compose
    ```

3. `docker-machine` target user to target host need to have sudo privileges without asking the root password, so add the below line to the remote target machine's `/etc/sudoers`.

    ```
    leonard ALL=(ALL) NOPASSWD:ALL
    ```

4. `docker-machine` has problems working with SSH `DSA` key, so use the SSH `RSA` key instead.

5. If you ever manually installed any docker-* component please purge them totally.

    ```
    sudo apt-get purge docker docker-engine
    ```

6. For elasticsearch cluster you need to config the `vm.max_map_count` in the /etc/sysctl.conf

    - [Issue #4978](https://github.com/elastic/elasticsearch/issues/4978#issuecomment-258676104)
    - [Elasticsearch virtual memory](https://www.elastic.co/guide/en/elasticsearch/reference/current/vm-max-map-count.html)

```
#!bash
  # So put the below line in the file /etc/sysctl.conf
  vm.max_map_count = 262144
```

## Construct RabbitMQ cluster manually

```
#!bash
  docker run -it --rm \
    --network=gate_services_stack \
    --link 24dcc271c547 \
    --env SERVICE_IGNORE=true \
    --env RABBITMQ_ERLANG_COOKIE=e705fb595df640baa6df37c0f967bd11 \
    --env RABBITMQ_NODENAME=rabbit@rabbitmq_server_2 \
    rabbitmq:3.6.10-management-alpine bash

  rabbitmqctl stop_app

  rabbitmqctl join_cluster rabbit@rabbitmq_server_0

  rabbitmqctl start_app
```

  - You can check cluster status with `rabbitmqctl cluster_status`.

  - You can remove one node by using: `rabbitmqctl forget_cluster_node rabbit@rabbitmq_server_2`

  - Due to [Issue #151](https://github.com/docker-library/rabbitmq/issues/151) `RABBITMQ_HIPE_COMPILE=1` cannot work as expected.

  - RabbitMQ cluster with the below 2 policies:

```
#!json

      {
        "name": "ha-gate-mq-*",
        "priority": 999,
        "pattern": "^gate-mq-",
        "definition": {
          "ha-mode": "exactly",
          "ha-params": 2,
          "ha-sync-mode": "automatic"
        }
      }

      {
        "name": "ha-gate-ex-*",
        "priority": 999,
        "pattern": "^gate-ex-",
        "definition": {
          "ha-mode": "exactly",
          "ha-params": 2,
          "ha-sync-mode": "automatic"
        }
      }
```

## Generate user and password for registry

```
#!bash
    mkdir auth
    docker run --entrypoint htpasswd registry:2 -Bbn leonard 1234567890 > auth/htpasswd
```

- Check what images you have by using `https://micro02.sgdev.vcube.com:65300/v2/_catalog`

- How to remove one tag:

```
#!bash

      # Get tags list.
      curl -u leonard:1234567890 -H 'Accept: application/vnd.docker.distribution.manifest.v2+json' https://micro02.sgdev.vcube.com:65300/v2/auth_dev_leonard_0.0.1/tags/list

      # Get manifest for selected tag.
      curl -i -u leonard:1234567890 -H 'Accept: application/vnd.docker.distribution.manifest.v2+json' https://micro02.sgdev.vcube.com:65300/v2/auth_dev_leonard_0.0.1/manifests/latest

      #
      ## Copy digest hash from response header.
      ## Delete manifest (soft delete). This request only marks image tag as deleted and doesn't delete files from file system.
      ## If you want to delete data from file system, run this step and go to the next step.
      #
      curl -i -u leonard:1234567890 -X DELETE -H 'Accept: application/vnd.docker.distribution.manifest.v2+json' https://micro02.sgdev.vcube.com:65300/v2/auth_dev_leonard_0.0.1/manifests/sha256:e55b7e2fcae56845cca6fcae0b667fb70b362e2e87756fbdca2b7e3bb03e0e67

      #
      ## Delete image data from file system.
      ## Run command from the host machine.
      #
      docker exec -it 0ada19d5b37e bin/registry garbage-collect /etc/docker/registry/config.yml
```

## Create email server

- Generate dkim

```
#!bash
      apt-get install opendkim-tools

      opendkim-genkey -s mail -d {domain name you will use for the email server}
```

- Just put the file `mail.private` as `dkim.key` inside the dkim directory you'll later link into the container using `-v`.

- The `mail.txt` should be imported into the DNS System. Add a new TXT-Record for mail._domainkey [selector._domainkey]. And add as value the String starting "`v=DKIM1;...`" from the `mail.txt` file.

-  Verify your email server works properly with `telnet`

```
#!bash
      echo -ne '\0support\0L6b8c38fb30664cdb25382d201893c1f' | openssl enc -base64
      # AHN1cHBvcnQATDZiOGMzOGZiMzA2NjRjZGIyNTM4MmQyMDE4OTNjMWY=

      telnet 10.0.3.159 65000

      ehlo test

      auth plain AHN1cHBvcnQATDZiOGMzOGZiMzA2NjRjZGIyNTM4MmQyMDE4OTNjMWY=

      mail from: support@microservices.vcube.sg

      rcpt to: leonard.shi@vcube.co.jp

      data

      From: "V-CUBE Gate" <support@microservices.vcube.sg>
      To: "Leonard Shi" <leonard.shi@vcube.co.jp>
      Subject: How is the new architecture going?

      Hi Leonard,

      How is the new architecture going? Can we arrange a meeting for some deeper discussion?

      BR,
      V-CUBE

      .
```

## Under each project's root directory, build and push your image to our private registries, take project `microservice-auth-jwt` as example

- Basically to say, the image tag should follow this format: `protobuf service name` **-** `dev/stg/prd` **-** `owner` **-** `target cpu cores` **:** `version`

```
#!bash
      # Build your image.
      docker build \
        --no-cache=true \
        --pull=true \
        --compress=false \
        --rm=true \
        --force-rm=true \
        --build-arg PORTS_END=53547 \
        --tag auth-dev-leonard-1:0.0.1 \
        .

      # Tag your image.
      docker tag auth-dev-leonard-1:0.0.1 micro02.sgdev.vcube.com:65300/auth-dev-leonard-1:0.0.1

      # Login to the corresponding registry.
      docker login micro02.sgdev.vcube.com:65300

      # Push your image to the registry.
      docker push micro02.sgdev.vcube.com:65300/auth-dev-leonard-1:0.0.1
```

- Since

    1. docker supports by using the `--cpuset-cpus=""` option to control the CPU resource;

    2. Consul supports grouping multiple service instances under one service name;

    3. Avoid the case that running more than 2 service instances in one physical node;

- So

    - On the image we add the `target cpu cores` option also, if necessary then prepare the image.

## Build fluentd image with elastic-search plugin

```
#!bash
  docker build \
    --no-cache=true \
    --pull=true \
    --compress=false \
    --rm=true \
    --force-rm=true \
    --tag fluentd-ms-leonard \
    --file ./Dockerfiles/Dockerfile.fluentd \
    .

  # Tag your image.
  docker tag fluentd-ms-leonard micro02.sgdev.vcube.com:65300/fluentd-ms-leonard

  # Login to the corresponding registry.
  docker login micro02.sgdev.vcube.com:65300

  # Push your image to the registry.
  docker push micro02.sgdev.vcube.com:65300/fluentd-ms-leonard
```

## Set up your localhost testing environment.

```
#!bash

  # Install Docker CE.
  https://docs.docker.com/docker-for-mac/install/#download-docker-for-mac

  # Init docker swarm cluster.
  docker swarm init

  # Create necessary network.
  docker network create \
    --driver overlay \
    --attachable=true \
    --subnet 172.29.0.0/16 \
    gate_services_stack

  # Run registrator
  docker service create \
    --name registrator \
    --network gate_services_stack \
    --mount type=bind,src=/var/run/docker.sock,dst=/tmp/docker.sock,readonly \
    --restart-condition any \
    gliderlabs/registrator:master \
    -cleanup \
    -deregister always \
    consul://micro01.sgdev.vcube.com:65499

  #
  ## Bring the target project up by running 'run.sh' in its root directory.
  #
  ## -n to specify whether you need to run npm install.
  ## -w to specify the owner of this env.
  #
  source run.sh -n -w leonard

```


