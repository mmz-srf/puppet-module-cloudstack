require File.join(File.dirname(__FILE__), '../../../util/cloudstack_client')

Puppet::Type.type(:cloudstack_secondary_ip).provide(:cloudstack) do
  include CloudstackClient::Helper

  desc "Provider for the CloudStack secondary ip."

  def self.instances
    extend CloudstackClient::Helper
    instances = []
    params = {
        'command' => 'listVirtualMachines',
    }
    params['projectid'] = project['id'] if project
    json = api.send_request(params)

    raise "Could not get list of virtual machines" unless json.has_key?('virtualmachine')

    json['virtualmachine'].each do |virtualmachine|
      vm = api.list_nics(virtualmachine['id'])
      vm['nic'].each do |nic_item|
        next unless nic_item.has_key?('secondaryip')
        nic_item['secondaryip'].each do |sip_item|
          name = "#{sip_item['ipaddress']}"
          instances << new(
            :name => name,
            :virtual_machine_id => virtualmachine['id'],
            :nic_id => nic_item['id'],
            :ipaddress => sip_item['ipaddress']
          )
        end
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
    api.add_ip_to_virtualmachine(@resource[:virtual_machine_id], @resource[:ipaddress])
  end

  def destroy
    api.remove_ip_from_virtualmachine(@resource[:virtual_machine_id], @resource[:ipaddress])
  end

  def exists?
    debug("Checking existance of secondary ip #{@resource['ipaddress']}")
    self.class.instances.each do |instance|
      next unless instance.get(:name) == @resource['ipaddress']
      return true
    end

    false
  end

end
