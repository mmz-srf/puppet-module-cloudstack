define cloudstack::firewall_rule (
  $front_ip,
  $cidrlist = '0.0.0.0/0',
  $startport,
  $endport,
  $protocol = 'tcp',
) {
  debug("${caller_module_name}->${module_name} : Configuring Firewallrule for ${front_ip} [source cidr:${cidrlist}, start port:${startport}, end port:${endport}, protocol:${protocol}]")

  @@cloudstack_firewall_rule {"$::fqdn/$cidrlist/$startport/$endport/$protocol/$name":
    ensure             => present,
    front_ip           => $front_ip,
    cidrlist           => $cidrlist,
    startport          => $startport,
    endport            => $endport,
    protocol           => $protocol,
    virtual_machine_id => $::instance_id,
  }
}
