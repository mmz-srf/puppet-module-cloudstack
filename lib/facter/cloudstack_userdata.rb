# cloudstack_userdata.rb:
#
# This script will load the userdata associated with a CloudStack
# guest VM into a collection of puppet facts. It is assumed that
# the userdata is formated as key=value pairs, one pair per line.
# For example, if you set your userdata to "role=foo\nenv=development\n"
# two facts would be created, "role" and "env", with values
# "foo" and "development", respectively.
#
# A guest VM can get access to its userdata by making an http
# call to its virtual router. We can determine the IP address
# of the virtual router by inspecting the dhcp lease file on
# the guest VM.
#
# Copyright (c) 2012 Jason Hancock <jsnbyh@gmail.com>
# Copyright (c) 2013 Simon Josi <me@yokto.net>
#
# Permission is hereby granted, free of charge, to any person obtaining a copy
# of this software and associated documentation files (the "Software"), to deal
# in the Software without restriction, including without limitation the rights
# to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
# copies of the Software, and to permit persons to whom the Software is furnished
# to do so, subject to the following conditions:
#
# The above copyright notice and this permission notice shall be included in all
# copies or substantial portions of the Software.
#
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
# IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
# FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
# AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
# LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
# OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
# THE SOFTWARE.

require 'facter'
require 'net/http'
require 'socket'
require 'timeout'

ENV['PATH']='/bin:/sbin:/usr/bin:/usr/sbin'

# The dirs to search for the dhcp lease files in.
# Works for RHEL/CentOS and Ubuntu
lease_dirs = %w{
  /var/lib/dhclient
  /var/lib/dhcp3
  /var/lib/dhcp
}
metadata = %w{
  service-offering
  availability-zone
  local-ipv4
  local-hostname
  public-ipv4
  public-hostname
  instance-id
}

def is_port_open?(ip, port)
  begin
    Timeout::timeout(1) do
      begin
        s = TCPSocket.new(ip, port)
        s.close
        return true
      rescue Errno::ECONNREFUSED, Errno::EHOSTUNREACH
        return false
      end
    end
  rescue Timeout::Error
  end

  return false
end

lease_dirs.each do |lease_dir|
  next unless File.directory? lease_dir

  Dir.glob(File.join(lease_dir, 'dhclient*eth0*lease*')).each do |file|
    next unless File.size?(file)

    virtual_router = File.open(file).grep(/dhcp-server-identifier/).last
    next unless virtual_router
    virtual_router = virtual_router[/\d+(\.\d+){3}/]

    next unless is_port_open?(virtual_router, 80)
    http = Net::HTTP.new(virtual_router)

    http.get('/latest/user-data').body.each_line do |line|
      next unless line[/=/]
      key, value = line.match(/([-\w]+)\s*=\s*([-\w]+)/)[1,2]
      Facter.add(key.gsub('-','_')) do
        setcode { value }
      end
    end

    metadata.each do |key|
      #begin
        #value = http.get("/latest/meta-data/#{key}")
      #rescue
        value = http.get("/latest/#{key}").body
      #end
      Facter.add(key.gsub('-','_')) do
        setcode { value }
      end
    end

  end
end