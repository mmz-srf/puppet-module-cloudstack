require 'ipaddr'

Puppet::Type.newtype(:cloudstack_loadbalancer) do
  @doc = "Manages a Service entry on the Loadbalancer:

    cloudstack_loadbalancer{'www.example.com':
      ensure => 'present',
      algorithm => 'roundrobin',
      privateport => '80',
      publicport => '80',
      vip => '192.168.1.1',
      projectname => 'Playground',
    }"

  ensurable

  newparam(:name, :namevar => true) do
    desc "The record to manage"
    isnamevar
  end

  newparam(:vip) do
    desc "The virtual IP of the load balancer service"
    validate do |value|
      fail("Invalid source #{value}") unless (IPAddr.new(value) rescue false)
    end
  end

  newparam(:algorithm) do
    desc "load balancer algorithm (roundrobin, source, leastconn)"
    defaultto 'roundrobin'
    newvalues('roundrobin', 'source', 'leastconn')
  end

  newparam(:privateport) do
    desc "Private load balancer port"
    newvalues(/[0-9]{1,5}/)
  end

  newparam(:publicport) do
    desc "Public load balancer port"
    newvalues(/[0-9]{1,5}/)
  end
end

