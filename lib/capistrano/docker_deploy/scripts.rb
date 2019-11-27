# frozen_string_literal: true

require "time"

module Capistrano
  module DockerDeploy
    class Scripts
      def initialize(context)
        @context = context
      end

      # Build a custom command line start script with the configuration arguments for
      # each docker application on the host. This allows each app to be started with
      # the predefined configuration by calling `bin/start app`.
      def start_script(host)
        apps = Array(fetch_for_host(host, :docker_apps))
        cmd = "exec bin/docker-cluster"
        image_id = fetch(:docker_image_id)
        prefix = fetch(:docker_prefix)

        cases = []
        apps.each do |app|
          args = app_host_args(app, host)
          cases << "  '#{app}')\n    #{cmd} #{args.join(' ')} --name '#{prefix}#{app}' --image '#{image_id}' ${args[*]}\n    ;;"
        end

        <<~BASH
          #!/usr/bin/env bash

          # Generated: #{Time.now.utc.iso8601}
          # Docker image tag: #{fetch(:docker_repository)}/#{fetch(:docker_tag)}

          set -o errexit

          cd $(dirname $0)/..

          typeset app=$1
          shift

          declare -a args
          typeset count=$#
          for ((index=0; index<count; ++index)); do
            typeset arg="$(printf "%q" "$1")"
            args[index]="$(printf "%q" "$arg")"
            shift
          done

          case $app in
          #{cases.join("\n")}
            *)
              >&2 echo "Usage: $0 #{apps.join('|')}"
              exit 1
          esac
        BASH
      end

      # Build a custom command line run script with the configuration arguments for
      # each docker application on the host to run one off containers.
      def run_script(host)
        apps = Array(fetch_for_host(host, :docker_apps))
        cmd = "exec bin/docker-cluster"
        image_id = fetch(:docker_image_id)

        cases = []
        apps.each do |app|
          args = app_host_args(app, host)
          cases << "  '#{app}')\n    #{cmd} #{args.join(' ')} --image '#{image_id}' --one-off ${args[*]}\n    ;;"
        end

        <<~BASH
          #!/usr/bin/env bash

          # Generated: #{Time.now.utc.iso8601}
          # Docker image tag: #{fetch(:docker_repository)}/#{fetch(:docker_tag)}

          set -o errexit

          cd $(dirname $0)/..

          typeset app=$1
          shift

          declare -a args
          typeset count=$#
          for ((index=0; index<count; ++index)); do
            typeset arg="$(printf "%q" "$1")"
            args[index]="$(printf "%q" "$arg")"
            shift
          done

          case $app in
          #{cases.join("\n")}
            *)
              >&2 echo "Usage: $0 #{apps.join('|')}"
              exit 1
          esac
        BASH
      end

      # Build a custom command line stop script for each docker application on the host.
      def stop_script(host)
        apps = Array(fetch_for_host(host, :docker_apps))
        prefix = fetch(:docker_prefix)

        cases = []
        all = []
        apps.each do |app|
          cases << "  '#{app}')\n    exec bin/docker-cluster --name '#{prefix}#{app}' --count 0\n    ;;"
        end

        <<~BASH
          #!/usr/bin/env bash

          # Generated: #{Time.now.utc.iso8601}
          # Docker image tag: #{fetch(:docker_repository)}/#{fetch(:docker_tag)}

          set -o errexit

          cd $(dirname $0)/..

          typeset app=$1

          case $app in
          #{cases.join("\n")}
            *)
              >&2 echo "Usage: $0 #{apps.join('|')}"
              exit 1
          esac
        BASH
      end

      # Returns a list of all local configuration file paths that need to be uploaded to
      # the host.
      def docker_config_map(host)
        configs = {}
        Array(fetch(:docker_configs)).each do |path|
          configs[File.basename(path)] = path
        end

        apps = Array(fetch_for_host(host, :docker_apps))

        app_configs = app_configuration(fetch(:docker_app_configs, nil))
        apps.each do |app|
          Array(app_configs[app.to_s]).each do |path|
            configs[File.basename(path)] = path
          end
        end

        Array(host.properties.docker_configs).each do |path|
          configs[File.basename(path)] = path
        end

        host_app_configs = app_configuration(host.properties.send(:docker_app_configs))
        apps.each do |app|
          Array(host_app_configs[app.to_s]).each do |path|
            configs[File.basename(path)] = path
          end
        end

        configs
      end

      # Fetch a host specific property. If a the value is not defined as host specific,
      # then fallback to the globally defined property.
      def fetch_for_host(host, property, default = nil)
        host.properties.send(property) || fetch(property, default)
      end

      private

      # Helper to fetch a property defined in the capistrano script.
      def fetch(property, default = nil)
        @context.fetch(property, default)
      end

      # Helper to normalize used to multiple configurations keyed by the app name
      # to ensure that the keys are all strings.
      def app_configuration(hash)
        hash ||= {}
        config = {}
        hash.each do |key, value|
          config[key.to_s] = value
        end
        config
      end

      # Translate a list of config file paths into command line arguments for the docker_clusther.sh command.
      def config_args(config_files)
        Array(config_files).collect{ |path| "--config 'config/#{File.basename(path)}'" }
      end

      def app_host_args(app, host)
        config_args = config_args(fetch(:docker_configs, nil))
        command_args = Array(fetch(:docker_args, nil))

        host_config_args = config_args(host.properties.send(:docker_configs))
        host_command_args = Array(host.properties.send(:"docker_args"))

        app_configs = app_configuration(fetch(:docker_app_configs, {}))
        app_args = app_configuration(fetch(:docker_app_args, {}))

        host_app_configs = app_configuration(host.properties.send(:"docker_app_configs"))
        host_app_args = app_configuration(host.properties.send(:"docker_app_args"))

        app = app.to_s
        app_config_args = config_args(app_configs[app])
        app_command_args = Array(app_args[app])
        host_app_config_args = config_args(host_app_configs[app])
        host_app_command_args = Array(host_app_args[app])
        args = config_args + command_args + app_config_args + app_command_args + host_config_args + host_command_args + host_app_config_args + host_app_command_args
        args.uniq
      end
    end
  end
end
