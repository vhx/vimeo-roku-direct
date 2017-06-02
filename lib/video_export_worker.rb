require 'sidekiq'
require 'vimeo_me2'
require 'pry-remote'
require 'vhx'

Sidekiq.configure_server do |config|
  config.redis = { url: ENV['REDIS_URL'] || "redis://localhost:6379" }
end

class VideoExportWorker
  include Sidekiq::Worker

  def perform(platform_token, vhx_token, vimeo_video_id)
    vimeo_video = VimeoMe2::Video.new(platform_token, vimeo_video_id).video

    vhx = Vhx.setup({
      api_key: vhx_token
    })

    # HAX TODO: VHX test env???
    # Vhx::Video.create(
    #  vimeo_to_vhx_arguments(vimeo_video)
    # )
  end

  private

  def vimeo_to_vhx_arguments(vimeo_video)
    {
      title: vimeo_video['name'],
      description: vimeo_video['description'],
      source_url: source_location(vimeo_video),
      metadata: {
        custom_icon: thumbnail_location(vimeo_video),
      },
    }
  end

  def thumbnail_location(vimeo_video)
    vimeo_video['pictures'].sort_by{|thumb| thumb['width'] }.last['link'] if vimeo_video['pictures'].is_a?(Array)
  end

  def source_location(vimeo_video)
    return @source_location if @source_location 
    source_files = []
    source_files += vimeo_video['files']&.select { |link| link['quality'] == 'source' || link['width'] == 1920 }
    source_files += vimeo_video['download']&.select { |link| link['quality'] == 'source' || link['width'] == 1920 }
    raise 'No quality files' if source_files.empty?
    source_file = source_files.sort_by { |link| link['quality'] }.last
    interim_location = source_file['link_secure'] 
    interim_location ||= source_file['link']
    raise 'No valid link in Vimeo' if interim_location.nil? || interim_location == ''
    @source_location = HTTParty.head(interim_location, follow_redirects: false)['location']
    @source_location ||= interim_location
  end
end