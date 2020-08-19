define cloudstack::port_forwarding (
  $front_ip,
  $port,
  $protocol    = 'tcp',
  $vm_guest_ip = "0.0.0.0",
  $cidrlist    = '0.0.0.0/0',
) {

  debug("${caller_module_name}->${module_name} : Configuring Firewallrule for ${front_ip} [source cidr:${cidrlist}, start port:${port}, end port:${port}, protocol:${protocol}]")
  @@cloudstack_firewall_rule {"$::fqdn/$cidrlist/$port/$protocol/$name":
    ensure             => present,
    front_ip           => $front_ip,
    cidrlist           => $cidrlist,
    startport          => $port,
    endport            => $port,
    protocol           => $protocol,
  }

  debug("${caller_module_name}->${module_name} : Configuring Portforwarding for ${front_ip} -> $vm_guest_ip, protocol:${protocol}, port:${port}")
  @@cloudstack_port_forwarding {"$::fqdn/$vm_guest_ip/$protocol/$name":
    ensure             => present,
    front_ip           => $front_ip,
    protocol           => $protocol,
    privateport        => $port,
    publicport         => $port,
    virtual_machine_id => $::instance_id,
    vm_guest_ip        => $vm_guest_ip,
  }

}
