# frozen_string_literal: true

require 'capistrano/scm/none'

require_relative "docker_deploy/version"
require_relative "docker_deploy/scripts"

load File.expand_path("tasks/docker_deploy.rake", __dir__)

install_plugin Capistrano::Scm::None::Plugin