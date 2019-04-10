# Capistrano Docker Deploy

This gem provides a recipe to use capistrano to deploy docker applications.

This allows you to deploy an application across a cluster of servers running docker. There are, of course, other methods of doing this (kubernetes, docker-compose, etc.). This method can fill a nitch of allowing you to dockerize your application but keep the deployment simple and use existing configs if you're already deploying via capistrano.

You application will be deployed by pulling a tag from a docker repository on the remote servers and then starting it up as a cluster using the `bin/docker_cluster` script. This script will start a cluster of docker containers by spinning up a specified number of containers from the same image and configuration. It does this gracefully by first shutting down any excess containers and then restarting the containers one at a time. The script can perform an optional health check to determine if a container is fully running before shutting down the next contaner.

If you specify a port mapping for the containers, the container ports will be mapped to incrementing host ports so you can run multiple server containers fronted by a load balancer.

The full set of arguments can be found in the `bin/docker-cluster` script.

## Configuration

The deployment is configured with the following properties in your capistrano recipe.

* docker_repository - The URI for the repository where to pull images from. If you are building images on the docker host (i.e. for a staging server), this can just be the local respoitory.

* docker_tag - The tag of the image to pull for starting the containers.

* docker_roles - List of server roles that will run docker containers. This defaults to `:docker`, but you can change it to whatever server roles you have in your recipe.

* docker_user - User to use when running docker commands on the remote host. This user must have access to the docker daemon. Default to the default capistrano user.

* docker_env - Environment variables needed to run docker commands. You may need to set `HOME` if you are pulling docker images from a remote repository using a use that is not the default deploy user.

* docker_apps - List of apps to deploy. Each app is deployed to its own containers with its own configuration. This value should usually be defined on a server role.

* docker_configs - List of global configuration files for starting all containers.

* docker_app_configs - Map of configuration files for starting specific docker apps.

* docker_args - List of global command line arguments for all continers.

* docker_app_args - Map of command line arguments for starting specific docker apps.

### Example Configuration

```
set :docker_repository, repository.example.com/myapp

set :docker_tag, ENV.fetch("tag")

# Define two apps; the web app will run on both server01 and server02
role :web, [server01, server02], user: 'app', docker_apps: [:web]
role :async, [server01], user: 'app', docker_apps: [:async]

# These configuration files will apply to all containers
set :docker_configs, ["config/volumes.properties"]

# Unlike config files, args can be dynamically generated at runtime
set :docker_args, ["--env=ASSET_HOST=#{ENV.fetch('asset_host')}"]

# These configuration files and args will apply only to each app.
set :docker_app_configs, {
  web: ["config/web.properties"],
  async: ["config/async.properties"]
}

set :docker_app_args, {
  web: ["--env=SERVER_HOST=#{fetch(:server_host)}"]
}

# If your capistrano user doesn't have access to the docker daemon, you can specify a different user.
set :docker_user, "root"

# You can also specify environment variables that may be needed for running docker commands.
set :docker_env, {"HOME" => "/root"}
```

## Remote Repository

If your `docker_repository` points to a remote repository, then the tag specified by `docker_tag` will be pulled from that repository during the deploy. If the repository requires authentication, then you should implement the `docker:authenticate` task to authenticate all servers in the `docker_role` role with the repository. You can use the `as_docker_user` method to run docker commands as the user specified in `docker_user`.

### Example Authentication with Amazon ECR

```
namespace :docker do
  task :authenticate do
    ecr_login_path = "/tmp/ecr_login_#{SecureRandom.hex(8)}"
    on release_roles(fetch(:docker_roles)) do |host|
      begin
        upload! StringIO.new(ecr_login_script), ecr_login_path
        execute :chmod, "a+x", ecr_login_path
        as_docker_user do
          execute ecr_login_path
        end
      ensure
        execute :rm, ecr_login_path
      end
    end
  end
end

# Script to run the aws ecr get-login results, but with passing the password in
# via STDIN so that it doesn't appear in the capistrano logs.
def ecr_login_script
  <<~BASH
    #!/usr/bin/env bash

    set -o errexit

    read -sra cmd < <(/usr/bin/env aws ecr get-login --no-include-email)
    pass="${cmd[5]}"
    unset cmd[4] cmd[5]
    /usr/bin/env "${cmd[@]}" --password-stdin <<< "$pass"
  BASH
end
```

## Building Docker Image

If you need to build the docker image on the remote host as part of the deploy (for example if you're deploying pre-release code to a staging server), you can implement the `docker:build` task to build your docker image. You must also tag the image with the value in the `:docker_tag` property.
