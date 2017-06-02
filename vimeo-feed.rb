require 'vimeo_me2'
require 'redis'
require 'time'
require 'pp'
require 'pry-remote'
require 'sidekiq'
require_relative 'lib/video_export_worker'

class VimeoFeed
  def initialize(vimeo_token = nil)
    @vimeo_token = vimeo_token || ENV['VIMEO_ACCESS_TOKEN']
  end

  def run(vhx_token = '')
    next_page = '/me/videos'
    video_uris = []

    loop do
      raw = fetch_results(next_page)
      break if raw.nil? || raw['data'].nil? || raw['total'] < 1

      raw['data'].each do |video_rep|
        next if video_rep['uri'].nil? || video_rep['uri'] == ''
        video_uris.push(video_rep['uri'])
        # HAX TODO: perform_async
        VideoExportWorker.new.perform(
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

  def fetch_results(endpoint)
    token = @vimeo_token
    raise 'No VIMEO_ACCESS_TOKEN defined' if token.nil? || token.empty?
    puts "Fetching #{endpoint} ..."
    VimeoMe2::Video.new(token, endpoint).video
  end
end
