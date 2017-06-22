require 'sidekiq'
require 'pry-remote'
require 'vhx'

class VhxContentUploadWorker
  include Sidekiq::Worker

  sidekiq_retry_in do |count|
    60 * 60
  end

  def perform(vhx_token, vimeo_video_hash)

    vhx = Vhx.setup(
      vhx_client_options(vhx_token)
    )

    Vhx::Video.create(
      vhx_video_arguments(vimeo_video_hash)
    )
  end

  protected

  def vhx_video_arguments(vimeo_video_hash)
    {
      title: vimeo_video_hash['name'],
      description: vimeo_video_hash['description'],
      source_url: source_location(vimeo_video_hash),
      metadata: {
        custom_icon: thumbnail_location(vimeo_video_hash),
      },
    }
  end

  def use_vhx_key
    ENV['USE_VHX_KEY'] == 'true'
  end

  def vhx_client_options(vhx_token)
    return @base_options if @base_options
    raise 'Not provided VHX credentials' if argument_is_nil_or_blank(vhx_token)

    if use_vhx_key == true
      @base_options = { api_key: vhx_token }
    else
      @base_options = { oauth_token: { token: vhx_token} }
    end

    @base_options[:api_base] = ENV['VHX_API_LOCATION'] unless argument_is_nil_or_blank(
      ENV['VHX_API_LOCATION']
    )
    return @base_options
  end

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
    source_files += Array(vimeo_video['files']&.select { |link| link['quality'] == 'source' || link['height'] == 1920 })
    source_files += Array(vimeo_video['download']&.select { |link| link['quality'] == 'source' || link['height'] == 1920 })
    source_files = source_files.flatten.compact
    raise 'No quality files' if source_files.empty?
    source_file = source_files.sort_by { |link| link['quality'] }.last
    interim_location = source_file['link_secure'] 
    interim_location ||= source_file['link']
    raise 'No valid link in Vimeo' if argument_is_nil_or_blank(interim_location)
    @source_location = HTTParty.head(interim_location, follow_redirects: false)['location']
    @source_location ||= interim_location
  end

  def argument_is_nil_or_blank(obj)
    obj.nil? || obj == ''
  end
end
