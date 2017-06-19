require 'vimeo_me2'
require 'redis'
require 'time'
require 'sidekiq'
require './vimeo-feed'

class VimeoCollectionWorker
  include Sidekiq::Worker
   sidekiq_options unique: :until_timeout,
    unique_expiration: 120 * 60 # 2 hours


  def perform(vimeo_token, vhx_key)
    VimeoFeed.new(
      vimeo_token
    ).run(
      vhx_key
    )
  end
end
