require_relative 'boot'

require 'rails/all'
require 'active_record_extended'

# Require the gems listed in Gemfile, including any gems
# you've limited to :test, :development, or :production.
Bundler.require(*Rails.groups)

require_relative '../lib/util/id_protector'

module BostonHmis
  class Application < Rails::Application
    # Initialize configuration defaults for originally generated Rails version.
    config.load_defaults 6.1
    # config.autoloader = :classic
    config.autoload_paths << Rails.root.join('lib', 'devise')

    # ActionCable
    config.action_cable.mount_path = "/cable"
    config.action_cable.url = ENV.fetch('ACTION_CABLE_URL') { "wss://#{ENV['FQDN']}/cable" }

    Rails.application.config.active_record.belongs_to_required_by_default = true
    # https://discuss.rubyonrails.org/t/cve-2022-32224-possible-rce-escalation-bug-with-serialized-columns-in-active-record/81017
    # config.active_record.yaml_column_permitted_classes = [Symbol, Date, Time]
    config.active_record.use_yaml_unsafe_load = true

    # Use the responders controller from the responders gem
    config.app_generators.scaffold_controller :responders_controller

    # Settings in config/environments/* take precedence over those specified here.
    # Application configuration should go into files in config/initializers
    # -- all .rb files in that directory are automatically loaded.

    # Set Time.zone default to the specified zone and make Active Record auto-convert to this zone.
    # Run "rake -D time" for a list of tasks for finding time zone names. Default is UTC.
    # config.time_zone = 'Central Time (US & Canada)'
    config.time_zone = ENV.fetch('TIMEZONE') { 'America/New_York' }

    # The default locale is :en and all translations from config/locales/*.rb,yml are auto loaded.
    # config.i18n.load_path += Dir[Rails.root.join('my', 'locales', '*.{rb,yml}').to_s]
    config.i18n.default_locale = :en

    config.action_controller.include_all_helpers = false

    config.active_record.schema_format = ENV.fetch('SCHEMA_FORMAT') { 'sql' }.to_sym

    config.active_job.queue_adapter = :delayed_job
    config.action_mailer.deliver_later_queue_name = :mailers

    config.generators do |generate|
      generate.helper false
      generate.assets false
      generate.test_framework :rspec
    end

    require_relative("setup_logging")
    setup_logging = SetupLogging.new(config)
    setup_logging.run!

    # default to not be sandbox email mode
    config.sandbox_email_mode = false

    # additional library paths
    config.eager_load_paths << Rails.root.join('lib', 'util')
    config.eager_load_paths << Rails.root.join('lib', 'devise')

    # serve error pages from the Rails app itself
    # rather than using static error pages in public/.
    config.exceptions_app = self.routes

    config.middleware.use Rack::Attack # needed pre rails 5.1
    config.middleware.use IdProtector

    # FIXME: required to make forms in pjax modals work
    config.action_controller.per_form_csrf_tokens = false

    # Extension points
    config.sub_populations = {}
    config.census = {}
    config.monthly_reports = {}
    config.hud_reports = {}
    config.hmis_importers = []
    config.hmis_exporters = []
    config.synthetic_event_types = []
    config.synthetic_assessment_types = []
    config.synthetic_youth_education_status_types = []
    config.patient_dashboards = []
    config.hmis_migrations = {}
    config.hmis_data_lake = nil
    config.custom_imports = []
    config.supplemental_enrollment_importers = {}
    config.help_links = []
    config.location_processors = []
  end
end
