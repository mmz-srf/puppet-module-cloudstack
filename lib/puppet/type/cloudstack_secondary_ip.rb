require 'ipaddr'

module Puppet
  newtype(:cloudstack_secondary_ip) do
    @doc = "Manages a secondary ip rule in CloudStack:

      cloudstack_secondary_ip{'rule_name':
        ensure => 'present',
        virtual_machine_id,
        ipaddress
      }"

    ensurable

    newparam(:name, :namevar => true) do
      desc "The name of the rule to manage"
      isnamevar
    end

    newparam(:virtual_machine_id) do
      desc "Cloudstack ID of the virtual machine"
    end

    newparam(:ipaddress) do
      desc "Secondary IP address"
      validate do |value|
        fail("Invalid source #{value}") unless (IPAddr.new(value) rescue false)
      end
    end
  end # Type
end # Module
