# frozen_string_literal: true

require_relative 'boot'

require 'rails/all'

# Require the gems listed in Gemfile, including any gems
# you've limited to :test, :development, or :production.
Bundler.require(*Rails.groups)

module WeatherLineBot
  class Application < Rails::Application
    config.load_defaults 5.2

    # 設定
    config.time_zone = 'Tokyo'
    config.i18n.default_locale = :ja
  end
end
