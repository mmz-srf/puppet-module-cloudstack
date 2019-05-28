require File.join(File.dirname(__FILE__), '../../../../../../forge/cloudstack/lib/util/cloudstack_client')

module Puppet::Parser::Functions
  newfunction(:add_vm_tag, :type => :rvalue) do |args|

    virtual_machine_name = args[0]
    key                  = args[1]
    value                = args[2]

    if virtual_machine_name.empty?() then
      fail('add_vm_tag requires a virtual machine name')
    end

    if key.empty?() then
      fail('add_vm_tag requires a tag key')
    end

    if value.empty?() then
      fail('add_vm_tag requires a tag value')
    end

    cc = Object.new
    cc.extend(CloudstackClient::Helper)

    project = cc.get_project
    project_id = project['id']

    vm = cc.api.get_server(virtual_machine_name, project_id)
    tags = cc.api.get_tags_for_resource(project_id, 'UserVM', vm['id'])

    if tags[0]['key'] == key and tags[0]['value'] == value
      # Do nothing, tag already exists
      true
    else
      if vm then
        # Add tag as it doesn't exist yet
        cc.api.add_tag_for_resource(project_id, 'UserVM', vm['id'], key, value)
      else
        err "Could not get data for VM from Cloudstack API."
        false
      end
      true
    end
  end
end
