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

      token = '72ba5ed97bce41ba5d04b721c451d62f'
      site_token = locate_site_key(site_id)

      VimeoCollectionWorker.perform_async(
        token,
        site_token
      )

      erb :success
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
end
