require 'redis'
require 'time'
require 'pp'
require 'pry-remote'
require 'sidekiq'
require 'httparty'
require_relative 'lib/video_export_worker'

class VimeoFeed
  def initialize(vimeo_token = nil)
    @vimeo_token = vimeo_token || ENV['VIMEO_ACCESS_TOKEN']
  end

  def run(vhx_token = '')
    next_page = '/me/videos?fields=uri'
    video_uris = []

    loop do
      raw = fetch_results(next_page)
      break if raw.nil? || raw['data'].nil? || raw['total'] < 1

      raw['data'].each do |video_rep|
        next if video_rep['uri'].nil? || video_rep['uri'] == ''
        video_uris.push(video_rep['uri'])
        VideoExportWorker.perform_async(
          @vimeo_token,
          vhx_token,
          video_rep['uri']
        )
        puts "Enqueued #{video_rep['uri']}"
      end
      next_page = raw['paging']['next']
      break if next_page.nil? || next_page.empty?
    end

    video_uris.to_json
  end

  protected

  def vimeo_api_location
    ENV['VIMEO_API_LOCATION'] || 'https://api.vimeo.com'
  end

  def auth_header
    raise 'No VIMEO_ACCESS_TOKEN defined' if @vimeo_token.nil? || @vimeo_token.empty?
    { 'Authorization' => "Bearer #{@vimeo_token}" }
  end

  def fetch_results(endpoint)
    uri = "#{vimeo_api_location}#{endpoint}"
    puts "Fetching #{uri} ..."
    res = HTTParty.get(uri, headers: auth_header)

    process(res)
  end

  def process(res)
    raise 'Vimeo Rate Limit Hit' if res.code == 429
    raise "Vimeo Returned: #{res.code}" if res.code != 200

    JSON.parse(res.body)
  end
end
