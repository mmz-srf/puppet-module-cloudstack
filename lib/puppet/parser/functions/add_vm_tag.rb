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

    if vm then
      tags = cc.api.get_tags_for_resource(project_id, 'UserVM', vm['id'])
      tags.each do |tag|
        if tag['key'] == key then
          if tag['value'] == value then
            # Do nothing, tag already exists
            setTag = false
            break
          end
        end
      end

      if setTag then
        # Add tag as it doesn't exist yet
        cc.api.add_tag_for_resource(project_id, 'UserVM', vm['id'], key, value)
      end
    else
      err "Could not get data for VM from Cloudstack API."
      false
    end
    true
  end
end
