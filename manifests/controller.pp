# Configure a Cloudstack controller 
#
# The controller server makes the API calls to Cloudstack to create
# loadbalancing rules, portforwarding rules, etc.
#
# == Parameters ==
#
# [url]
# *Mandatory* The URL of the Cloudstack API
# [api_key]
# *Mandatory* The Cloudstack API Key
# [secret_key]
# *Mandatory* The Cloudstack Secret Key
# [project]
# *Mandatory* The Cloudstack Project for the controller 
#
class cloudstack::controller(
  $url,
  $api_key,
  $secret_key,
  $project,
){
    file{'/etc/cloudstack.yaml':
    content => "url:  '$url'\napi_key:  '$api_key'\nsecret_key:  '$secret_key'\nproject:  '$project'\n",
    owner => root, group => 0, mode => '0444';
  }
}
