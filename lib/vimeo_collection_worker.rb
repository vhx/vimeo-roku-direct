require 'redis'
require 'time'
require 'sidekiq'
require 'httparty'
require './vimeo-feed'

class VimeoCollectionWorker
  include Sidekiq::Worker

  def perform(vimeo_token, vhx_key)
    VimeoFeed.new(
      vimeo_token
    ).run(
      vhx_key
    )
  end
end
