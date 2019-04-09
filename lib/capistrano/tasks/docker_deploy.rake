# frozen_string_literal: true

set :docker_roles, [:docker]

def as_docker_user
  user = fetch(:docker_user, nil)
  if user
    as(user) do
      with(fetch(:docker_env, {})) do
        yield
      end
    end
  else
    yield
  end
end

namespace :deploy do
  after :new_release_path, "docker:create_release"
  before :set_current_revision, "docker:set_image_id"
  after :updating, "docker:update"
  after :published, "docker:restart"
end

namespace :docker do
  desc "create the docker release directory and pull the image if necessary"
  task :create_release do
    on release_roles(fetch(:docker_roles)) do
      execute :mkdir, "-p", release_path
    end

    if fetch(:docker_repository).include?("/")
       invoke "docker:pull"
    end
  end

  task :set_image_id do
    on release_roles(fetch(:docker_roles)).first do
      docker_tag_url =  "#{fetch(:docker_repository)}:#{fetch(:docker_tag)}"
      as_docker_user do
        image_id = capture(:docker, "image", "ls", "--no-trunc", "--format", "'{{.ID}}'", docker_tag_url)
        set :docker_image_id, image_id[7, 12]
      end
    end
  end

  desc "Update the configuration and command line arguments for running a docker deployment."
  task :update do
    invoke("docker:copy_configs")
    invoke("docker:upload_commands")
  end

  desc "Prune the docker engine of all unused images, containers, and volumes."
  task :prune do
    on release_roles(fetch(:docker_roles)) do |host|
      as_docker_user do
        execute :docker, "system", "prune", "--volumes", "--force"
      end
    end
  end

  desc "Pull a tag from a remote into the local docker engine. If the task docker:authenticate is defined, it will be invoked first."
  task :pull do
    docker_tag_url =  "#{fetch(:docker_repository)}:#{fetch(:docker_tag)}"
    if Rake::Task.task_defined?('docker:authenticate')
      invoke "docker:authenticate"
    end
    on release_roles(fetch(:docker_roles)) do |host|
      as_docker_user do
        execute :docker, "pull", docker_tag_url
      end
    end
  end

  desc "Restart the docker containers (alias to docker:start)."
  task :restart do
    invoke("docker:start")
  end

  desc "Restart the docker containers."
  task :start do
    on release_roles(fetch(:docker_roles)) do |host|
      within "#{fetch(:deploy_to)}/current" do
        scripts = Capistrano::DockerDeploy::Scripts.new(self)
        Array(scripts.fetch_for_host(host, :docker_apps)).each do |app|
          as_docker_user do
            execute "bin/start", app
          end
        end
      end
    end
  end

  desc "Stop the docker containers."
  task :stop do
    on release_roles(fetch(:docker_roles)) do |host|
      within "#{fetch(:deploy_to)}/current" do
        scripts = Capistrano::DockerDeploy::Scripts.new(self)
        Array(scripts.fetch_for_host(host, :docker_apps)).each do |app|
          as_docker_user do
            execute "bin/stop", app
          end
        end
      end
    end
  end

  desc "Upload the commands to stop and start the application docker containers."
  task :upload_commands do
    on release_roles(fetch(:docker_roles)) do |host|
      within fetch(:release_path) do
        execute(:mkdir, "-p", "bin")
        scripts = Capistrano::DockerDeploy::Scripts.new(self)
        docker_deploy_path = File.join(__dir__, "..", "..", "..", "bin", "docker-cluster")
        upload! docker_deploy_path, "bin/docker-cluster"
        upload! StringIO.new(scripts.start_script(host)), "bin/start"
        upload! StringIO.new(scripts.stop_script(host)), "bin/stop"
        upload! StringIO.new(scripts.run_script(host)), "bin/run"
        execute :chmod, "a+x", "bin/*"
      end
    end
  end

  desc "Copy configuration files used to start the docker containers."
  task :copy_configs do
    on release_roles(fetch(:docker_roles)) do |host|
      configs = Capistrano::DockerDeploy::Scripts.new(self).docker_config_map(host)
      unless configs.empty?
        within fetch(:release_path) do
          execute(:mkdir, "-p", "config")
          configs.each do |name, local_path|
            upload! local_path, "config/#{name}"
          end
        end
      end
    end
  end
end
