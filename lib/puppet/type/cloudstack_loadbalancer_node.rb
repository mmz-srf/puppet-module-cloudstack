Puppet::Type.newtype(:cloudstack_loadbalancer_node) do
  @doc = "Manages a node entry on a existing loadbalancer config::

    @@cloudstack_loadbalancer_node{'www.example.com/$hostname':
      ensure => 'present',
      service => 'www.example.com'
      hostname => $hostname
    }"

  ensurable

  newparam(:name, :namevar => true) do
    desc "The record to manage"
    isnamevar
  end

  newparam(:service) do
    desc "Name of the service"
  end

  newparam(:hostname) do
    desc "Name of the host"
  end
end

