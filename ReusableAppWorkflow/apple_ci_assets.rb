#!/usr/bin/env ruby
# Tracks temporary Apple Development signing assets Xcode creates on an
# ephemeral GitHub-hosted Mac and removes only development assets created by
# the current run.

require 'base64'
require 'json'
require 'net/http'
require 'openssl'
require 'time'
require 'uri'

API_BASE = 'https://api.appstoreconnect.apple.com'.freeze
DEVELOPMENT_CERT_TYPES = %w[DEVELOPMENT IOS_DEVELOPMENT].freeze
DEVELOPMENT_PROFILE_TYPES = %w[IOS_APP_DEVELOPMENT].freeze

KEY_ID = ENV.fetch('APP_STORE_CONNECT_KEY_ID')
ISSUER_ID = ENV.fetch('APP_STORE_CONNECT_ISSUER_ID')
KEY_PATH = ENV.fetch('KEY_PATH')

def b64url(data)
  Base64.urlsafe_encode64(data, padding: false)
end

def jwt
  now = Time.now.to_i
  header = { alg: 'ES256', kid: KEY_ID, typ: 'JWT' }
  payload = { iss: ISSUER_ID, iat: now - 5, exp: now + 600, aud: 'appstoreconnect-v1' }
  signing_input = [b64url(JSON.generate(header)), b64url(JSON.generate(payload))].join('.')
  key = OpenSSL::PKey.read(File.read(KEY_PATH))
  der_signature = key.sign(OpenSSL::Digest::SHA256.new, signing_input)
  sequence = OpenSSL::ASN1.decode(der_signature)
  raw_signature = sequence.value.map do |integer|
    hex = integer.value.to_i.to_s(16).rjust(64, '0')
    raise 'Unexpected ES256 signature component size' if hex.length > 64
    [hex].pack('H*')
  end.join
  raise "Unexpected ES256 signature length: #{raw_signature.bytesize}" unless raw_signature.bytesize == 64
  "#{signing_input}.#{b64url(raw_signature)}"
end

def api_request(method, path)
  uri = URI("#{API_BASE}#{path}")
  request = method == :get ? Net::HTTP::Get.new(uri) : Net::HTTP::Delete.new(uri)
  request['Authorization'] = "Bearer #{jwt}"
  request['Accept'] = 'application/json'
  response = Net::HTTP.start(uri.host, uri.port, use_ssl: true, open_timeout: 15, read_timeout: 30) { |http| http.request(request) }
  raise "Apple API #{method.to_s.upcase} #{path} failed (HTTP #{response.code}): #{response.body}" unless response.code.to_i.between?(200, 299)
  response.body.to_s.empty? ? {} : JSON.parse(response.body)
end

def list_certificates
  query = URI.encode_www_form([['limit', '200'], ['fields[certificates]', 'name,displayName,certificateType,expirationDate']])
  api_request(:get, "/v1/certificates?#{query}").fetch('data', [])
end

def list_profiles
  query = URI.encode_www_form([['limit', '200'], ['fields[profiles]', 'name,profileType,createdDate,expirationDate']])
  api_request(:get, "/v1/profiles?#{query}").fetch('data', [])
end

def development_certificates
  list_certificates.select { |item| DEVELOPMENT_CERT_TYPES.include?(item.dig('attributes', 'certificateType')) }
end

def development_profiles
  list_profiles.select { |item| DEVELOPMENT_PROFILE_TYPES.include?(item.dig('attributes', 'profileType')) }
end

def snapshot(path)
  data = {
    'capturedAt' => Time.now.utc.iso8601,
    'certificateIds' => development_certificates.map { |item| item.fetch('id') },
    'profileIds' => development_profiles.map { |item| item.fetch('id') }
  }
  File.write(path, JSON.pretty_generate(data))
  puts "Apple signing baseline saved: #{data['certificateIds'].length} development certificate(s), #{data['profileIds'].length} development profile(s)."
end

def cleanup(path)
  baseline = JSON.parse(File.read(path))
  baseline_cert_ids = baseline.fetch('certificateIds', [])
  baseline_profile_ids = baseline.fetch('profileIds', [])
  sleep 1
  new_profiles = development_profiles.reject { |item| baseline_profile_ids.include?(item.fetch('id')) }
  new_certificates = development_certificates.reject { |item| baseline_cert_ids.include?(item.fetch('id')) }
  new_profiles.each { |item| api_request(:delete, "/v1/profiles/#{item.fetch('id')}") }
  new_certificates.each { |item| api_request(:delete, "/v1/certificates/#{item.fetch('id')}") }
  puts "Apple signing cleanup complete: removed #{new_certificates.length} certificate(s) and #{new_profiles.length} profile(s) created by this run."
end

command = ARGV[0]
path = ARGV[1]
abort 'Usage: apple_ci_assets.rb snapshot|cleanup SNAPSHOT_PATH' unless %w[snapshot cleanup].include?(command) && path

begin
  command == 'snapshot' ? snapshot(path) : cleanup(path)
rescue => error
  if command == 'snapshot'
    File.delete(path) if File.exist?(path)
    warn 'Warning: Apple signing asset tracking unavailable; continuing release without automatic cleanup.'
    warn error.message
    exit 0
  end
  raise
end
