require 'sidekiq'
require 'sidekiq/web'
require 'redis'
require './app'

Sidekiq.configure_client do |config|
  config.redis = { url: ENV['REDIS_URL'] }
end

Sidekiq.configure_server do |config|
  config.redis = { url: ENV['REDIS_URL'] }
end

Sidekiq::Web.use(Rack::Auth::Basic) do |username, password|
  [username, password] == ['christopherf', ENV['SIDEKIQ_PASSWORD']]
end

run Rack::URLMap.new('/' => App, '/sidekiq' => Sidekiq::Web)
