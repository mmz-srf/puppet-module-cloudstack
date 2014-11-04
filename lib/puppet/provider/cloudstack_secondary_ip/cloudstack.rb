require File.join(File.dirname(__FILE__), '../../../util/cloudstack_client')

Puppet::Type.type(:cloudstack_secondary_ip).provide(:cloudstack) do
  include CloudstackClient::Helper

  desc "Provider for the CloudStack secondary ip."

  def self.instances
    extend CloudstackClient::Helper
    instances = []
    params = {
        'command' => 'listNics',
    }
    params['projectid'] = project['id'] if project
    json = api.send_request(params)
    if not json.has_key?('nic')
      fail("could not get network interface listing")
    end
    json['nic'].each do |nic_item|
      if nic_item.has_key?('secondaryip')
        nic_item['secondaryip'].each do |sip_item|
          instances << new(
            :name => sip_item['ipaddress'],
            :id   => sip_item['id']
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
    false
  end

  def destroy
    false
  end

  def exists?
    self.class.instances.each do |instance|
      if instance.get(:name) == "#{@resource[:ipaddress]}"
        return true
      end
    end
    return false
  end
end
