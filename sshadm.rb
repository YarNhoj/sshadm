#!/usr/bin/env ruby

require 'rubygems'
require 'aws-sdk'
require 'sshkit'
require 'sshkit/dsl'
require 'optparse'

def get_instances(config,options,nodes)

  site = options[:site] 
  id = config[site]['id']
  key = config[site]['key']
  region = config[site]['region']

  ec2 = AWS::EC2.new(
    :access_key_id => id,
    :secret_access_key => key,
    :region => region
  )
  ec2.instances.filter('instance-state-name', 'running').filter('tag:Name', nodes)
end


# Parse Options
# Need to add logic for:
# multiple sites
# define hosts/list of hosts at invocation read from stdin regardless
# Define user at invocation default to user who is running the script
#
# Initialize Arrays
options = {}
nodes = [] 

# Load Site Configuration
config = YAML::load(File.open('sites.yaml'))

optparse = OptionParser.new do |opts|
	opts.banner = "Usage: sshadm [options]"
	opts.on('-v','--verbose','Output more information') do
    SSHKit.config.output_verbosity = :debug
	end
	opts.on('-s SITE','--site','AWS site id') do |s|
	  options[:site] = s
	end
	options[:execute_flag] = nil
	opts.on('-e','--execute','Do not capture output') do
	 options[:execute_flag] = 'true' 
	end
  opts.on('-h host','--hosts HOSTS', Array,'Comma seperated list of hosts to work on') do |h|
    nodes = h
  end
	opts.on('-l','--list','List AWS site ids') do
		config.each do |s|
			puts s[0]
		end
		exit
	end
	opts.on('-c CMD','--command','Remote Command to Execute') do |c|
		options[:cmd] = c
	end
	opts.on('--help','Display this screen') do 
		puts opts
  	exit
	end
end
optparse.parse!


# Configure Logging
#class MyFormatter < SSHKit::Formatter::Abstract
#	  def write(obj)
#			    case obj.is_a? SSHKit::Command
#						      # Do something here, see the SSHKit::Command documentation
#						     end
#						       end
#						       end
#						
#SSHKit.config.output = MyFormatter.new($stdout)
#SSHKit.config.output = MyFormatter.new(SSHKit.config.output)
#SSHKit.config.output =
#MyFormatter.new(File.open('log/deploy.log', 'wb'))
#SSHKit.config.output

# Set ssh defaults
SSHKit::Backend::Netssh.configure do |ssh|
	ssh.ssh_options = {
 	user: 'root',
  auth_methods: ['publickey','password']
	}
end

#binding.pry
#
#Set command block
if options[:execute_flag].nil?
	command = Proc.new{puts capture(:"#{options[:cmd]}",{:raise_on_non_zero_exit=>false})}
else
	command = Proc.new{execute(:"#{options[:cmd]}",{:raise_on_non_zero_exit=>false})}
end

AWS.memoize do
  nodes = $stdin.readlines if nodes.empty?
	nodes.map!(&:chomp)
	instances = get_instances(config,options,nodes)
	hosts = instances.collect(&:private_ip_address)
	on(hosts,{},&command)
end
