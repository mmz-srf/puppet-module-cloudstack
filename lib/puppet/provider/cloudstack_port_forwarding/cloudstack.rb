require File.join(File.dirname(__FILE__), '../../../util/cloudstack_client')

Puppet::Type.type(:cloudstack_port_forwarding).provide(:cloudstack) do
  include CloudstackClient::Helper

  desc "Provider for the CloudStack port forwarding."

  def self.instances
    extend CloudstackClient::Helper
    instances = []
    params = {
      'command' => 'listPortForwardingRules',
      'listall' => 'true'
    }
    params['projectid'] = project['id'] if project
    json = api.send_request(params)
    if json.has_key?('portforwardingrule')
      json['portforwardingrule'].each do |pf_rule|
        instances << new(
          :name => "#{pf_rule['ipaddress']}_#{pf_rule['virtualmachineid']}_#{pf_rule['privateport']}_#{pf_rule['publicport']}_#{pf_rule['protocol'].downcase}",
          :front_ip => pf_rule['ipaddress'],
          :privateport => pf_rule['privateport'],
          :publicport => pf_rule['publicport'],
          :protocol => pf_rule['protocol'],
          :virtual_machine => pf_rule['virtualmachinename'],
          :virtual_machine_id => pf_rule['virtualmachineid'],
          :ensure => :present
        )
      end
    end
    instances
  end
  
  def self.prefetch(resources)
    instances.each do |instance|
      if resource = resources[instance.name]
        resource.provider = instance
      end
    end
  end
  
  def create
    params = {
      'command' => 'createPortForwardingRule',
      'protocol' => @resource[:protocol],
      'publicport' => @resource[:publicport],
      'privateport' => @resource[:privateport],
      'ipaddressid' => public_ip_address['id'],
      'virtualmachineid' => @resource[:virtual_machine_id],
      'openfirewall' => 'true',
    }
    api.send_request(params)
    true
  end

  def destroy
    front_ip = public_ip_address(@resource[:front_ip])
    
    params = {
      'command' => 'listPortForwardingRules',
      'ipaddressid' => front_ip['id']
    }
    params['projectid'] = project['id'] if project
    json = api.send_request(params)
    port_forwarding_rules = json['portforwardingrule']
    
    rule = port_forwarding_rules.find do |rule|
      rule['protocol'] == @resource[:protocol] &&
      rule['publicport'] == @resource[:publicport] &&
      rule['privateport'] == @resource[:privateport] &&
      rule['virtualmachineid'] == @resource[:virtual_machine_id]
    end
    if rule
      params = {
        'command' => 'deletePortForwardingRule',
        'id' => rule['id']
      }
      api.send_request(params)
    end
    true
  end

  def exists?
    self.class.instances.each do |instance|
      if instance.get(:name) == "#{@resource[:front_ip]}_#{@resource[:virtual_machine_id]}_#{@resource[:privateport]}_#{@resource[:publicport]}_#{@resource[:protocol].downcase}"
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
