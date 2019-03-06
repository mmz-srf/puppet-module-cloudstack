require 'ipaddr'

Puppet::Type.newtype(:cloudstack_port_forwarding) do
  @doc = "Manages a port forwarding rule in CloudStack:

    cloudstack_port_forwarding{'rule_name':
      ensure => 'present',
      front_ip,
      protocol,
      privateport,
      publicport,
      virtual_machine,
      virtual_machine_id,
      vm_guest_ip => unset
    }"

  ensurable

  newparam(:name, :namevar => true) do
    desc "The name of the rule to manage"
    isnamevar
  end

  newparam(:front_ip) do
    desc "The virtual IP of the port forwarding rule"
    validate do |value|
      fail("Invalid source #{value}") unless (IPAddr.new(value) rescue false)
    end
  end

  newparam(:publicport) do
    desc "Public port"
    newvalues(/[0-9]{1,5}/)
  end

  newparam(:privateport) do
    desc "Private port"
    newvalues(/[0-9]{1,5}/)
  end
  
  newparam(:virtual_machine) do
    desc "Name of the virtual machine"
  end
  
  newparam(:virtual_machine_id) do
    desc "Cloudstack ID of the virtual machine"
  end

  newparam(:protocol) do
    desc "The protocol of the port forwarding rule"
    defaultto 'tcp'
    newvalues('TCP', 'UDP', 'tcp', 'udp')
  end

  newparam(:vm_guest_ip) do
    desc "IP of the guest VM"
    validate do |value|
      fail("Invalid vm_guest_ip #{value}") unless (IPAddr.new(value) rescue false)
    end
  end

  newparam(:private_end_port) do
    desc "Private END port"
    newvalues(/[0-9]{1,5}/)
  end

  newparam(:public_end_port) do
    desc "Public END port"
    newvalues(/[0-9]{1,5}/)
  end
end 
