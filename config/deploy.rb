require "bundler/capistrano"
require 'capistrano_colors'
# require 'thinking_sphinx/deploy/capistrano'

load "config/recipes/base"
load "config/recipes/nginx"
# load "config/recipes/sphinx"
load "config/recipes/unicorn"
load "config/recipes/postgresql"
load "config/recipes/nodejs"
load "config/recipes/rbenv"
load "config/recipes/check"
load 'deploy/assets'

server "198.101.226.25", :web, :app, :db, primary: true

set :user, "deployer"
set :application, "redmine"
set :deploy_to, "/home/#{user}/apps/#{application}"
set :deploy_via, :remote_cache
set :use_sudo, false

set :scm, "git"
set :repository, "git@github.com:1boson/#{application}.git"
set :branch, "master"

default_run_options[:pty] = true
ssh_options[:forward_agent] = true

namespace :redmine do
  desc "Make symlinks for config"
  task :symlink do
    run "ln -nfs #{shared_path}/files #{release_path}/files"
  end
end

after "deploy:update_code", "redmine:symlink"

after "deploy", "deploy:cleanup" # keep only the last 5 releases
