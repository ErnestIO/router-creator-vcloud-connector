# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.

require 'rubygems'
require 'bundler/setup'

require 'nats/client'
require 'net/http'
require 'net/https'
require 'json'
require 'base64'

def create_router(data)
  data[:ip] = vse_create_router(data)
  'router.create.vcloud.done'
rescue StandardError => e
  puts e
  data[:error] = { code: 0, message: e.to_s }
  'router.create.vcloud.error'
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
               'router-name'  => data[:name],
               'external-network' => data[:external_network] }.to_json
  req
end

def https_request(url, req)
  http = Net::HTTP.new(url.host, url.port)
  http.read_timeout = 720
  http.use_ssl = true
  res = http.start { |h| h.request(req) }
  raise res.message if res.code != '200'
  res.body
end

def path
  'router'
end

def decrypt

  data = "Very, very confidential data"

  cipher = OpenSSL::Cipher::AES.new(256, :CFB)
  cipher.encrypt
  key = cipher.random_key
  iv = cipher.random_iv

  encrypted = cipher.update(data) + cipher.final
  encrypted = Base64.decode64("b9a97c10635ecfa527baafaceb2372ad6255cbf649262b94")
  decipher = OpenSSL::Cipher::AES.new(256, :CFB)
  decipher.decrypt
  decipher.key = "mMYlPIvI11z20H1BnBmB223355667788"
  # decipher.iv = iv
  decipher.iv = "0x00, 0x01, 0x02, 0x03, 0x04, 0x05, 0x06, 0x07, 0x08, 0x09, 0x0a, 0x0b, 0x0c, 0x0d, 0x0e, 0x0f"

  plain = decipher.update(encrypted) + decipher.final

  puts data == plain #=> true

=begin
  data = Base64.encode64("b9a97c10635ecfa527baafaceb2372ad6255cbf649262b94")

  aes = OpenSSL::Cipher.new("AES-256-CFB")
  aes.decrypt
  aes.key = "mMYlPIvI11z20H1BnBmB223355667788"
  aes.iv = "0x00, 0x01, 0x02, 0x03, 0x04, 0x05, 0x06, 0x07, 0x08, 0x09, 0x0a, 0x0b, 0x0c, 0x0d, 0x0e, 0x0f"
  x = aes.update(data) + aes.final
  puts x
=end 
  require 'pry'; binding.pry


  puts 'upsuu'
end

decrypt

=begin
unless defined? @@test
  loop do
    begin
      NATS.start(servers: [ENV['NATS_URI']]) do
        NATS.subscribe 'router.create.vcloud' do |msg, _rply, sub|
          @data = { id: SecureRandom.uuid, type: sub }
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
=end
