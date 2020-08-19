require File.join(File.dirname(__FILE__), '../../../util/cloudstack_client')

Puppet::Type.type(:cloudstack_firewall_rule).provide(:cloudstack) do
  include CloudstackClient::Helper

  desc "Provider for the CloudStack firewall."

	def self.instances
    extend CloudstackClient::Helper
    
    instances = []
    params = {
      'command' => 'listFirewallRules',
      'listall' => 'true'
    }
    params['projectid'] = project['id'] if project
    json = api.send_request(params)
    if json.has_key?('firewallrule')
      json['firewallrule'].each do |fw_rule|
        instances << new(
          :name => "#{fw_rule['ipaddress']}_#{fw_rule['cidrlist']}_#{fw_rule['startport']}_#{fw_rule['endport']}_#{fw_rule['protocol']}",
          :front_ip => fw_rule['ipaddress'],
          :startport => fw_rule['startport'],
          :endport => fw_rule['endport'],
          :protocol => fw_rule['protocol'],
          :cidrlist => fw_rule['cidrlist'],
          :ensure => :present
        )
      end
    end
    instances
	end
	
	def self.prefetch(resources)
    instances.each do |prov|
      if resource = resources[prov.name]
        resource.provider = prov
      end
    end
  end

  def create
    params = {
      'command' => 'createFirewallRule',
      'protocol' => @resource[:protocol],
      'startport' => @resource[:startport],
      'endport' => @resource[:endport],
      'cidrlist' => @resource[:cidrlist],
      'ipaddressid' => public_ip_address['id'],
    }
    api.send_request(params)
    true
  end

  def destroy
    front_ip = public_ip_address(@resource[:front_ip])
    
    params = {
      'command' => 'listFirewallRules',
      'ipaddressid' => front_ip['id']
    }
    params['projectid'] = project['id'] if project
    json = api.send_request(params)
    firewall_rules = json['firewallrule']
    
    rule = firewall_rules.find do |rule|
      rule['protocol'] == @resource[:protocol] &&
      rule['startport'] == @resource[:startport] &&
      rule['endport'] == @resource[:endport] &&
      rule['cidrlist'] == @resource[:cidrlist]
    end
    if rule
      params = {
        'command' => 'deleteFirewallRule',
        'id' => rule['id']
      }
      api.send_request(params)
    end
    true
  end

  def exists?
    expected_name = "#{@resource['front_ip']}_#{@resource['cidrlist']}_#{@resource['startport']}_#{@resource['endport']}_#{@resource['protocol'].downcase}"
    debug("Checking presence of firewall rule for resouce for resource #{expected_name}")
    self.class.instances.each do |instance|
      if instance.get(:name) == expected_name
        return true
      end
    end
    return false
  end

  private
  
  def public_ip_address
    params = {
      'command' => 'listPublicIpAddresses',
      'ipaddress' => @resource[:front_ip],
    }
    params['projectid'] = project['id'] if project
    json = api.send_request(params)
    json['publicipaddress'].first
  end
end
