# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.

require 'rubygems'
require 'bundler/setup'

require 'nats/client'
require 'net/http'
require 'net/https'
require 'json'

def create_router(data)
  return false unless retry?(data)
  data[:router_ip] = vse_create_router(data)
  'router.create.vcloud.done'
rescue StandardError => e
  puts e
  data['error'] = { code: 0, message: e.to_s }
  'router.create.vcloud.error'
end

def retry?(data)
  data[:router_type] == 'vcloud' && data.values_at(:datacenter_name, :client_name).compact.length == 2
end

def vse_create_router(data)
  url = URI.parse("#{data[:vse_url]}/#{path}")
  req = prepare_request(url, data)
  response = JSON.parse(https_request(url, req))
  response['router_ip']
end

def prepare_request(url, data)
  credentials = data[:datacenter_username].split('@')
  req = Net::HTTP::Post.new(url.path)
  req.basic_auth data[:datacenter_username], data[:datacenter_password]
  req.body = { 'vdc-name'     => data[:datacenter_name],
               'org-name'     => credentials.last,
               'router-name'  => data[:router_name],
               'external-network' => data[:external_network] }.to_json
  req
end

def https_request(url, req)
  http = Net::HTTP.new(url.host, url.port)
  http.read_timeout = 720
  http.use_ssl = true
  res = http.start { |h| h.request(req) }
  fail res.message if res.code != '200'
  res.body
end

def path
  'router'
end

unless defined? @@test
  loop do
    begin
      NATS.start(servers: [ENV['NATS_URI']]) do
        NATS.subscribe 'router.create.vcloud' do |msg, _rply, sub|
          @data       = { id: SecureRandom.uuid, type: sub }
          @data.merge! JSON.parse(msg, symbolize_names: true)

          @data[:type] = create_router(@data)
          NATS.publish(@data[:type], @data.to_json)
        end
      end
    rescue NATS::ConnectError
      puts "Error connecting to nats on #{ENV['NATS_URI']}, retrying in 5 seconds.."
      sleep 5
    end
  end
end
