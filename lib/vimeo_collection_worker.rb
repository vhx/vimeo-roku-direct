require 'redis'
require 'time'
require 'sidekiq'
require 'httparty'
require './vimeo-feed'

class VimeoCollectionWorker
  include Sidekiq::Worker
  sidekiq_retry_in do |count|
    60 * 60
  end

  def perform(vimeo_token, vhx_key)
    VimeoFeed.new(
      vimeo_token
    ).run(
      vhx_key
    )
  end
end
