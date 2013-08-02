#
# Cookbook Name:: tickr
# Recipe:: default
#

# Ensure our apt cache is no more than one day old
include_recipe 'apt'

# Install mysql
include_recipe 'mysql::server'
# For some reason if we don't set this, it gets left blank on Ubuntu 12.04 on
# Rackspace. Probably a bug in the way the local NIC gets queried.
node.default['mysql']['bind_address'] = '127.0.0.1'

# Install git for application deploys
include_recipe 'git'

# Install build-essential for native gems
include_recipe 'build-essential'

# Unicorn runs the Sinatra app
include_recipe 'unicorn'

# Nginx is our frontend
include_recipe 'nginx'

# Set the node number based on the `node_number_mappings` hash
node.default['tickr']['node_number'] = node['tickr']['node_number_mappings'][node.name]

# Configure an application using its provided LWRPs.
TICKR_ENV = {
  'RACK_ENV' => node['RACK_ENV'],
  'TICKR_DATABASE_HOST' => 'localhost',
  'TICKR_DATABASE_USER' => 'root',
  'TICKR_DATABASE_PASSWORD' => node['mysql']['server_root_password'],
  'TICKR_DATABASE_NAME' => 'tickr',
  'TICKR_DATABASE_POOL_SIZE' => '5',
  'TICKR_DATABASE_POOL_TIMEOUT' => '5',
  'TICKR_MAX_NODES' => node['tickr']['max_nodes'].to_s,
  'TICKR_STARTING_OFFSET' => node['tickr']['starting_offset'].to_s,
  'TICKR_NODE_NUMBER' => node['tickr']['node_number'].to_s,
  'TICKR_HTTP_AUTH_PASSWORD' => node['tickr']['http_auth_password'].to_s
}

DEPLOY_DIR = '/opt/deploys/tickr'

application 'tickr' do
  path DEPLOY_DIR
  repository 'git@github.com:wistia/tickr-server.git'
  revision 'master'
  deploy_key node['tickr']['deploy_private_key']

  notifies :restart, 'service[tickr]' # This is broken. Tickr does not get notified on app deploy.

  action :deploy
end

node.default[:unicorn][:worker_timeout] = 60
node.default[:unicorn][:preload_app] = false
node.default[:unicorn][:worker_processes] = [node[:cpu][:total].to_i * 4, 8].min
node.default[:unicorn][:preload_app] = false
node.default[:unicorn][:before_fork] = 'sleep 1'
node.default[:unicorn][:port] = '8080'
node.default[:unicorn][:options] = {backlog: 100}

UNICORN_SOCKET_PATH = '/var/run/tickr-unicorn.sock'
UNICORN_PID_PATH = '/var/run/tickr-unicorn.pid'

LOG_DIR = '/var/log'

unicorn_config '/etc/unicorn/tickr.rb' do
  listen(UNICORN_SOCKET_PATH => node[:unicorn][:options])
  working_directory ::File.join(DEPLOY_DIR, 'current')
  worker_timeout node[:unicorn][:worker_timeout]
  preload_app node[:unicorn][:preload_app]
  worker_processes node[:unicorn][:worker_processes]
  before_fork node[:unicorn][:before_fork]
  pid UNICORN_PID_PATH
  stderr_path "#{LOG_DIR}/unicorn.stderr.log"
  stdout_path "#{LOG_DIR}/unicorn.stdout.log"

  notifies :restart, 'service[tickr]'
end

BIN_PATH = '/opt/chef/embedded/bin'
UNIX_PATH_MODIFICATION = "PATH=#{BIN_PATH}:$PATH"

execute 'install gems' do
  cwd '/opt/deploys/tickr/current'
  command "#{UNIX_PATH_MODIFICATION} bundle install --deployment"
  environment TICKR_ENV
end

ENV_PREFIX = TICKR_ENV.inject(''){|result, elem| "#{result} #{elem[0]}='#{elem[1].to_s}'"}

execute 'create database if it does not exist' do
  cwd "#{DEPLOY_DIR}/current"
  command "#{UNIX_PATH_MODIFICATION} rake db:create_if_not_exists --trace"
  environment TICKR_ENV
  ignore_failure true
end

service 'tickr' do
  provider Chef::Provider::Service::Upstart
  supports restart: true, start: true, stop: true, status: true
  action [:enable, :start]
end

template 'tickr-upstart' do
  path '/etc/init/tickr.conf'
  source 'tickr-upstart.conf.erb'
  variables({
    cmd: "cd #{DEPLOY_DIR}/current; #{ENV_PREFIX} #{UNIX_PATH_MODIFICATION} bundle exec unicorn -c /etc/unicorn/tickr.rb -E #{node['RACK_ENV']}"
  })
  owner 'root'
  group 'root'
  mode '0644'

  notifies :restart, 'service[tickr]'
end

nginx_site 'default' do
  enable false
end

template 'tickr-nginx' do
  path "#{node[:nginx][:dir]}/sites-available/tickr"
  source 'tickr-nginx.erb'
  variables({
    app_dir: "#{DEPLOY_DIR}/current",
    socket_path: UNICORN_SOCKET_PATH
  })
  owner 'root'
  group 'root'
  mode 0644

  notifies :restart, 'service[nginx]'
end

nginx_site 'tickr' do
  enable true

  notifies :restart, 'service[nginx]'
end

