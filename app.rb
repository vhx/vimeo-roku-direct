require 'rubygems'
require 'bundler/setup'
require 'dotenv'
Dotenv.load

require './vimeo-feed'
require 'sinatra/base'
require 'json'
require 'benchmark'
require 'omniauth'
require 'omniauth-vimeo'
require 'sidekiq'
require_relative 'lib/vimeo_collection_worker'

class App < Sinatra::Base
  use Rack::Session::Cookie
  use OmniAuth::Builder do
    provider :vimeo,
             ENV['VIMEO_MIGRATION_APP_KEY'],
             ENV['VIMEO_MIGRATION_APP_SECRET']
  end

  %w[get post].each do |method|
    send(method, '/auth/vimeo/callback') do
      site_id = request.env['omniauth.params']['site_id']
      token = request.env['omniauth.auth']['credentials']['token']

      error 400, 'missing params' if argument_is_nil_or_blank(site_id) ||
                                     argument_is_nil_or_blank(token)

      site_token = locate_site_key(site_id)

      if !request_submitted_recently(site_id)
        VimeoCollectionWorker.perform_async(
          token,
          site_token,
        )

        set_expiry(site_id)

        erb :success
      else
        erb :already_queued
      end
    end
  end

  post '/' do
    payload = JSON.parse(request.body.read, symbolize_names: true)
    payload[:provider_token] = '72ba5ed97bce41ba5d04b721c451d62f'
    error 400, 'missing params' if payload[:provider_token].nil? ||
                                   payload[:provider_token] == '' ||
                                   payload[:vhx_key].nil? ||
                                   payload[:vhx_key] == ''

    VimeoCollectionWorker.perform_async(
      payload[:provider_token],
      payload[:vhx_key]
    )
  end

  private

  def locate_site_key(subdomain)
    vhx_api_key = ENV[subdomain.upcase]
    error 500, 'No VHX API key present for that site' if argument_is_nil_or_blank(vhx_api_key)
    vhx_api_key
  end

  def argument_is_nil_or_blank(obj)
    obj.nil? || obj == ''
  end

  def redis_con
    @_redis_con ||= Redis.new
  end

  def redis_expiry_key(site_id)
    "#{site_id}_expiry"
  end

  def request_submitted_recently(site_id)
    expiry_seconds = redis_con.get(
      redis_expiry_key(site_id)
    )

    expiry_seconds.to_i > Time.now.to_i
  end

  def expiry_ttl_seconds
    @_expiry_time ||= 86400
  end

  def set_expiry(site_id)
    present_in_seconds = Time.now.to_i
    redis_con.setex(
      redis_expiry_key(site_id),
      expiry_ttl_seconds,
      expiry_ttl_seconds + present_in_seconds
    )
  end
end
