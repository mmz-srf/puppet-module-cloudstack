# CloudstackClient by Nik Wolfgramm (<nik.wolfgramm@swisstxt.ch>) based on 
# knife-cloudstack by Ryan Holmes (<rholmes@edmunds.com>), KC Braunschweig (<kcbraunschweig@gmail.com>)
# 
# License:: Apache License, Version 2.0
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#

require 'rubygems'
require 'base64'
require 'openssl'
require 'uri'
require 'cgi'
require 'net/http'
require 'json'
require 'yaml'

module CloudstackClient
  module Helper
    @api = nil
    @config = {}
    
    def api
      @api ||= load_api
    end
    
    def config
      @config ||= load_configuration
    end
    
    def load_configuration(config_file = '/etc/cloudstack.yaml')
      begin
        return YAML::load(IO.read(config_file))
      rescue Exception => e
        puts "Unable to load '#{config_file}'"
        exit
      end
    end
    
    def load_api
      config = load_configuration
			CloudstackClient::Connection.new(
				config['url'],
				config['api_key'],
				config['secret_key']
			)
    end
  end
  
  class Connection

    @@async_poll_interval = 2.0
    @@async_timeout = 300

    def initialize(api_url, api_key, secret_key)
      @api_url = api_url
      @api_key = api_key
      @secret_key = secret_key
    end

    ##
    # Finds the server with the specified name.

    def get_server(name, project_id=nil)
      params = {
          'command' => 'listVirtualMachines',
          'name' => name
      }
      params['projectid'] = project_id if project_id
      json = send_request(params)
      machines = json['virtualmachine']

      if !machines || machines.empty? then
        return nil
      end

      machines.first
    end

    def get_server_state(id)
      params = {
          'command' => 'listVirtualMachines',
          'id' => id
      }
      json = send_request(params)
      machine_state = json['virtualmachine'][0]['state']

      if !machine_state || machine_state.empty? then
        return nil
      end

      machine_state
    end

    def wait_for_server_state(id, state)
      while get_server_state(id) != state
        print '..'
	      sleep 5	
      end
      state
    end

    ##
    # Finds the public ip for a server

    def get_server_public_ip(server, cached_rules=nil)
      return nil unless server

      # find the public ip
      nic = get_server_default_nic(server) || {}
      if nic['type'] == 'Virtual' then
        ssh_rule = get_ssh_port_forwarding_rule(server, cached_rules)
        ssh_rule ? ssh_rule['ipaddress'] : nil
      else
        nic['ipaddress']
      end
    end

    ##
    # Returns the fully qualified domain name for a server.

    def get_server_fqdn(server)
      return nil unless server

      nic = get_server_default_nic(server) || {}
      networks = list_networks(server['projectid']) || {}

      id = nic['networkid']
      network = networks.select { |net|
        net['id'] == id
      }.first
      return nil unless network

      "#{server['name']}.#{network['networkdomain']}"
    end

    def get_server_default_nic(server)
      server['nic'].each do |nic|
        return nic if nic['isdefault']
      end
    end

    ##
    # Lists all the servers in your account.

    def list_servers(project_id=nil)
      params = {
          'command' => 'listVirtualMachines'
      }
      params['projectid'] = project_id if project_id
      json = send_request(params)
      json['virtualmachine'] || []
    end

    ##
    # Deploys a new server using the specified parameters.

    def create_server(host_name, service_name, template_name, zone_name=nil, network_names=[], project_id=nil)

      if host_name then
        if get_server(host_name) then
          puts "Error: Server '#{host_name}' already exists."
          exit 1
        end
      end

      service = get_service_offering(service_name)
      if !service then
        puts "Error: Service offering '#{service_name}' is invalid"
        exit 1
      end

      template = get_template(template_name)
      if !template then
        puts "Error: Template '#{template_name}' is invalid"
        exit 1
      end

      zone = zone_name ? get_zone(zone_name) : get_default_zone
      if !zone then
        msg = zone_name ? "Zone '#{zone_name}' is invalid" : "No default zone found"
        puts "Error: #{msg}"
        exit 1
      end

      networks = []
      network_names.each do |name|
        network = get_network(name, project_id)
        if !network then
          puts "Error: Network '#{name}' not found"
          exit 1
        end
        networks << network
      end
      if networks.empty? then
        networks << get_default_network
      end
      if networks.empty? then
        puts "No default network found"
        exit 1
      end
      network_ids = networks.map { |network|
        network['id']
      }

      params = {
          'command' => 'deployVirtualMachine',
          'serviceOfferingId' => service['id'],
          'templateId' => template['id'],
          'zoneId' => zone['id'],
          'networkids' => network_ids.join(','),
	  'projectid' => project_id
      }
      params['name'] = host_name if host_name

      json = send_async_request(params)
      json['virtualmachine']
    end

    ##
    # Deletes the server with the specified name.
    #

    def delete_server(name, project_id=nil)
      server = get_server(name, project_id)
      if !server || !server['id'] then
        puts "Error: Virtual machine '#{name}' does not exist"
        exit 1
      end

      params = {
          'command' => 'destroyVirtualMachine',
          'id' => server['id']
      }
      params['projectid'] = project_id if project_id

      json = send_async_request(params)
      json['virtualmachine']
    end

    ##
    # Stops the server with the specified name.
    #

    def stop_server(name, forced=nil)
      server = get_server(name)
      if !server || !server['id'] then
        puts "Error: Virtual machine '#{name}' does not exist"
        exit 1
      end

      params = {
          'command' => 'stopVirtualMachine',
          'id' => server['id']
      }
      params['forced'] = true if forced

      json = send_async_request(params)
      json['virtualmachine']
    end

    ##
    # Start the server with the specified name.
    #

    def start_server(name)
      server = get_server(name)
      if !server || !server['id'] then
        puts "Error: Virtual machine '#{name}' does not exist"
        exit 1
      end

      params = {
          'command' => 'startVirtualMachine',
          'id' => server['id']
      }

      json = send_async_request(params)
      json['virtualmachine']
    end

    ##
    # Reboot the server with the specified name.
    #

    def reboot_server(name)
      server = get_server(name)
      if !server || !server['id'] then
        puts "Error: Virtual machine '#{name}' does not exist"
        exit 1
      end

      params = {
          'command' => 'rebootVirtualMachine',
          'id' => server['id']
      }

      json = send_async_request(params)
      json['virtualmachine']
    end

    ##
    # Finds the service offering with the specified name.

    def get_service_offering(name)

      # TODO: use name parameter
      # listServiceOfferings in CloudStack 2.2 doesn't seem to work
      # when the name parameter is specified. When this is fixed,
      # the name parameter should be added to the request.
      params = {
          'command' => 'listServiceOfferings'
      }
      json = send_request(params)

      services = json['serviceoffering']
      return nil unless services

      services.each { |s|
        if s['name'] == name then
          return s
        end
      }

      nil
    end

    ##
    # Lists all available service offerings.

    def list_service_offerings
      params = {
          'command' => 'listServiceOfferings'
      }
      json = send_request(params)
      json['serviceoffering'] || []
    end

    ##
    # Finds the template with the specified name.

    def get_template(name)

      # TODO: use name parameter
      # listTemplates in CloudStack 2.2 doesn't seem to work
      # when the name parameter is specified. When this is fixed,
      # the name parameter should be added to the request.
      params = {
          'command' => 'listTemplates',
          'templateFilter' => 'executable'
      }
      json = send_request(params)

      templates = json['template']
      if !templates then
        return nil
      end

      templates.each { |t|
        if t['name'] == name then
          return t
        end
      }

      nil
    end

    ##
    # Lists all templates that match the specified filter.
    #
    # Allowable filter values are:
    #
    # * featured - templates that are featured and are public
    # * self - templates that have been registered/created by the owner
    # * self-executable - templates that have been registered/created by the owner that can be used to deploy a new VM
    # * executable - all templates that can be used to deploy a new VM
    # * community - templates that are public

    def list_templates(filter)
      filter ||= 'featured'
      params = {
          'command' => 'listTemplates',
          'templateFilter' => filter
      }
      json = send_request(params)
      json['template'] || []
    end

    ##
    # Finds the network with the specified name.

    def get_network(name, project_id = nil)
      params = {
          'command' => 'listNetworks'
      }
      params['projectid'] = project_id if project_id
      json = send_request(params)

      networks = json['network']
      return nil unless networks

      networks.each { |n|
        if n['name'] == name then
          return n
        end
      }

      nil
    end

    ##
    # Finds the default network.

    def get_default_network
      params = {
          'command' => 'listNetworks',
          'isDefault' => true
      }
      json = send_request(params)

      networks = json['network']
      return nil if !networks || networks.empty?

      default = networks.first
      return default if networks.length == 1

      networks.each { |n|
        if n['type'] == 'Direct' then
          default = n
          break
        end
      }

      default
    end

    ##
    # Lists all available networks.

    def list_networks(project_id = nil)
      params = {
          'command' => 'listNetworks'
      }
      params['projectid'] = project_id if project_id
      json = send_request(params)
      json['network'] || []
    end

    ##
    # Finds the zone with the specified name.

    def get_zone(name)
      params = {
          'command' => 'listZones',
          'available' => 'true'
      }
      json = send_request(params)

      networks = json['zone']
      return nil unless networks

      networks.each { |z|
        if z['name'] == name then
          return z
        end
      }

      nil
    end

    ##
    # Finds the default zone for your account.

    def get_default_zone
      params = {
          'command' => 'listZones',
          'available' => 'true'
      }
      json = send_request(params)

      zones = json['zone']
      return nil unless zones

      zones.first
    end

    ##
    # Lists all available zones.

    def list_zones
      params = {
          'command' => 'listZones',
          'available' => 'true'
      }
      json = send_request(params)
      json['zone'] || []
    end

    ##
    # Finds the public ip address for a given ip address string.

    def get_public_ip_address(ip_address)
      params = {
          'command' => 'listPublicIpAddresses',
          'ipaddress' => ip_address
      }
      json = send_request(params)
      json['publicipaddress'].first
    end


    ##
    # Acquires and associates a public IP to an account.

    def associate_ip_address(network_id)
      params = {
          'command' => 'associateIpAddress',
	  'networkid' => network_id
      }

      json = send_async_request(params)
      json['ipaddress']
    end

    ##
    # Disassociates an ip address from the account.
    #
    # Returns true if successful, false otherwise.

    def disassociate_ip_address(id)
      params = {
          'command' => 'disassociateIpAddress',
          'id' => id
      }
      json = send_async_request(params)
      json['success']
    end

    ##
    # Lists all port forwarding rules.

    def list_port_forwarding_rules(ip_address_id=nil)
      params = {
          'command' => 'listPortForwardingRules'
      }
      params['ipAddressId'] = ip_address_id if ip_address_id
      json = send_request(params)
      json['portforwardingrule']
    end

    ##
    # Gets the SSH port forwarding rule for the specified server.

    def get_ssh_port_forwarding_rule(server, cached_rules=nil)
      rules = cached_rules || list_port_forwarding_rules || []
      rules.find_all { |r|
        r['virtualmachineid'] == server['id'] &&
            r['privateport'] == '22'&&
            r['publicport'] == '22'
      }.first
    end

    ##
    # Creates a port forwarding rule.

    def create_port_forwarding_rule(ip_address_id, private_port, protocol, public_port, virtual_machine_id)
      params = {
          'command' => 'createPortForwardingRule',
          'ipAddressId' => ip_address_id,
          'privatePort' => private_port,
          'protocol' => protocol,
          'publicPort' => public_port,
          'virtualMachineId' => virtual_machine_id
      }
      json = send_async_request(params)
      json['portforwardingrule']
    end

    ##
    # Get projectn by name.

    def get_project(name)
      params = {
          'command' => 'listProjects',
          'name' => name
      }
      json = send_request(params)
      json['project'].first
    end

    ##
    # Lists projects.
            
    def list_projects
      params = {
          'command' => 'listProjects',
      }
      json = send_request(params)
      json['project'] || []
    end

		##
		#	List loadbalancer rules
		def list_loadbalancer_rules(project_name = nil)    
    	params = {
      	'command' => 'listLoadBalancerRules',
    	}
			if project_name
				project = get_project(project_name)
				params['projectid'] = project['id']
			end
    	json = send_request(params)
    	json['loadbalancerrule']
  	end


    ##
    # Sends a synchronous request to the CloudStack API and returns the response as a Hash.
    #
    # The wrapper element of the response (e.g. mycommandresponse) is discarded and the
    # contents of that element are returned.

    def send_request(params)
      params['response'] = 'json'
      params['apiKey'] = @api_key

      params_arr = []
      params.sort.each { |elem|
        params_arr << elem[0].to_s + '=' + elem[1].to_s
      }
      data = params_arr.join('&')
      encoded_data = URI.encode(data.downcase).gsub('+', '%20').gsub(',', '%2c')
      signature = OpenSSL::HMAC.digest('sha1', @secret_key, encoded_data)
      signature = Base64.encode64(signature).chomp
      signature = CGI.escape(signature)

      url = "#{@api_url}?#{data}&signature=#{signature}"

      response = Net::HTTP.get_response(URI.parse(url))

      if !response.is_a?(Net::HTTPOK) then
        puts "Error #{response.code}: #{response.message}"
        puts JSON.pretty_generate(JSON.parse(response.body))
        puts "URL: #{url}"
        exit 1
      end

      json = JSON.parse(response.body)
      json[params['command'].downcase + 'response']
    end

    ##
    # Sends an asynchronous request and waits for the response.
    #
    # The contents of the 'jobresult' element are returned upon completion of the command.

    def send_async_request(params)

      json = send_request(params)

      params = {
          'command' => 'queryAsyncJobResult',
          'jobId' => json['jobid']
      }

      max_tries = (@@async_timeout / @@async_poll_interval).round
      max_tries.times do
        json = send_request(params)
        status = json['jobstatus']

        print "."

        if status == 1 then
          return json['jobresult']
        elsif status == 2 then
          print "\n"
          puts "Request failed (#{json['jobresultcode']}): #{json['jobresult']}"
          exit 1
        end

        STDOUT.flush
        sleep @@async_poll_interval
      end

      print "\n"
      puts "Error: Asynchronous request timed out"
      exit 1
    end

  end # class
end
