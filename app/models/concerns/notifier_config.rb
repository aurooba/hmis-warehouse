###
# Copyright 2016 - 2023 Green River Data Analysis, LLC
#
# License detail: https://github.com/greenriver/hmis-warehouse/blob/production/LICENSE.md
###

module NotifierConfig
  extend ActiveSupport::Concern

  included do
    attr_accessor :notifier_config

    def setup_notifier(username)
      @notifier_config = Rails.application.config_for(:exception_notifier)&.fetch(:slack, nil)
      @send_notifications = notifier_config.present? && notifier_config[:webhook_url].present? && (Rails.env.development? || Rails.env.production? || ENV['FORCE_EXCEPTION_NOTIFIER'] == 'true')
      # return unless @send_notifications
      if @send_notifications
        slack_url = notifier_config[:webhook_url]
        channel   = notifier_config[:channel]
        @notifier = ApplicationNotifier.new(slack_url, channel: channel, username: username)
      else
        @notifier = ApplicationNotifier.new('')
      end
    end

    def self.send_single_notification(message, username)
      notifier_config = Rails.application.config_for(:exception_notifier)&.fetch(:slack, nil)
      return unless notifier_config.present? && notifier_config[:webhook_url].present? && (Rails.env.development? || Rails.env.production? || ENV['FORCE_EXCEPTION_NOTIFIER'] == 'true')

      slack_url = notifier_config[:webhook_url]
      channel   = notifier_config[:channel]
      notifier = ApplicationNotifier.new(slack_url, channel: channel, username: username)
      notifier.ping(message)
    end

    def send_single_notification(message, username)
      self.class.send_single_notification(message, username)
    end
  end
end
