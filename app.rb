require 'rubygems'
require 'bundler/setup'
require 'dotenv'
Dotenv.load

require './vimeo-feed'
require 'sinatra/base'
require 'json'
require 'benchmark'

class App < Sinatra::Base
  get '/' do
    'nope.'
  end

  post '/' do
    payload = JSON.parse(request.body.read, symbolize_names: true)
    # HAX TODO: Don't dump Jamie's videos
    payload[:provider_token] = '72ba5ed97bce41ba5d04b721c451d62f'
    error 400, 'missing params' if payload[:provider_token].nil? ||
                                   payload[:provider_token] == '' ||
                                   payload[:vhx_key].nil? ||
                                   payload[:vhx_key] == ''

    VimeoFeed.new(
      payload[:provider_token]
    ).run(
      payload[:vhx_key]
    )
  end
end
