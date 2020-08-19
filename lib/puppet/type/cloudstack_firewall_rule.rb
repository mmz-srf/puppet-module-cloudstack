require 'ipaddr'

Puppet::Type.newtype(:cloudstack_firewall_rule) do
    @doc = "Manages a firewall rules in CloudStack:

      cloudstack_firewall_rule{'ssh':
        ensure => 'present',
        front_ip,
        protocol,
        startport,
        endport,
        cidrlist
      }"

    ensurable

    newparam(:name, :namevar => true) do
      desc "The rule to manage"
      isnamevar
    end

    newparam(:front_ip) do
      desc "The virtual IP of the firewall rule"
      validate do |value|
        fail("Invalid source #{value}") unless (IPAddr.new(value) rescue false)
      end
    end

    newparam(:startport) do
      desc "Start port"
      newvalues(/[0-9]{1,5}/)
    end

    newparam(:endport) do
      desc "End port"
      newvalues(/[0-9]{1,5}/)
    end
    
    newparam(:cidrlist) do
      desc "Mask(s) of IPs permitted to the service"
      defaultto '0.0.0.0/0'
    end

    newparam(:protocol) do
      desc "The protocol of the firewall rule"
      defaultto 'TCP'
      newvalues('TCP', 'UDP')
    end

end # Typeß