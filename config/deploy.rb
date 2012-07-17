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

# namespace :ts do
#   task :conf do
#     thinking_sphinx.configure
#   end
#   task :in do
#     thinking_sphinx.index
#   end
#   task :start do
#     thinking_sphinx.start
#   end
#   task :stop do
#     thinking_sphinx.stop
#   end
#   task :restart do
#     thinking_sphinx.restart
#   end
#   task :rebuild do
#     thinking_sphinx.rebuild
#   end
# end

# namespace :deploy do
#   desc "Link up Sphinx's indexes."
#   task :symlink_sphinx_indexes, :roles => [:app] do
#     run "ln -nfs #{shared_path}/db/sphinx #{release_path}/db/sphinx"
#   end

#   task :activate_sphinx, :roles => [:app] do
#     symlink_sphinx_indexes
#     thinking_sphinx.configure
#     thinking_sphinx.start
#   end

#   before 'deploy:update_code', 'thinking_sphinx:stop'
#   after 'deploy:update_code', 'deploy:activate_sphinx'
# end

after "deploy", "deploy:cleanup" # keep only the last 5 releases
