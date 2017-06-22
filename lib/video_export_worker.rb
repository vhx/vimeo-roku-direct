require 'sidekiq'
require "sidekiq/throttled"
require 'pry-remote'
require 'vhx'

class VideoExportWorker
  include Sidekiq::Worker
  include Sidekiq::Throttled::Worker


  sidekiq_throttle({
    :concurrency => { :limit => 10 },
    :threshold => { :limit => 1, :period => 3600 } # one hour
  })

  sidekiq_retry_in do |count|
    60 * 60
  end

  def perform(platform_token, vhx_token, vimeo_video_uri)

    vhx = Vhx.setup(
      vhx_client_options(vhx_token)
    )

    Vhx::Video.create(
      vimeo_to_vhx_arguments(
        fetch_video(platform_token, vimeo_video_uri)
      )
    )
  end

  private

  def vimeo_api_location
    ENV['VIMEO_API_LOCATION'] || 'https://api.vimeo.com'
  end

  def auth_header(platform_token)
    { 'Authorization' => "Bearer #{platform_token}" }
  end

  def fetch_video(platform_token, vimeo_video_uri)
    uri = "#{vimeo_api_location}#{vimeo_video_uri}?#{filter_fields_query_param}"

    puts "Fetching #{uri} ..."
    res = HTTParty.get(uri, { headers: auth_header(platform_token) })
    return process(res)
  end

  def process(res)
    raise 'Vimeo Rate Limit Hit' if res.code == 429
    raise "Vimeo Returned: #{res.code}" if res.code != 200

   JSON.parse(res.body)
  end

  def filter_fields_query_param
    filters = %w(name description pictures files download).join(',')
    "fields=#{filters}"
  end

  def argument_is_nil_or_blank(obj)
    obj.nil? || obj == ''
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
    source_files += vimeo_video['files']&.select { |link| link['quality'] == 'source' || link['width'] == 1920 }
    source_files += vimeo_video['download']&.select { |link| link['quality'] == 'source' || link['width'] == 1920 }
    raise 'No quality files' if source_files.empty?
    source_file = source_files.sort_by { |link| link['quality'] }.last
    interim_location = source_file['link_secure'] 
    interim_location ||= source_file['link']
    raise 'No valid link in Vimeo' if argument_is_nil_or_blank(interim_location)
    @source_location = HTTParty.head(interim_location, follow_redirects: false)['location']
    @source_location ||= interim_location
  end
end
