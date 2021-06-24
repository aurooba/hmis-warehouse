###
# Copyright 2016 - 2021 Green River Data Analysis, LLC
#
# License detail: https://github.com/greenriver/hmis-warehouse/blob/production/LICENSE.md
###

class BaseJob < ApplicationJob
  STARTING_PATH = File.realpath(FileUtils.pwd)
  include NotifierConfig

  # when queued with Delayed::Job.enqueue TestJob.new (this gets used)
  # This will send two notifications for each error, probably
  def error(_job, exception)
    notify_on_exception(exception)
  end

  private

  def notify_on_exception(exception)
    return unless File.exist?('config/exception_notifier.yml')

    setup_notifier('DelayedJobFailure')
    return unless @send_notifications

    msg = [
      "*#{self.class.name}* `FAILED` with the following error:",
      "```\n #{exception.inspect} \n```",
    ].join("\n")
    attachment = "```\n #{Rails.backtrace_cleaner.clean(exception.backtrace).join("\n")} \n```"
    @notifier.post(text: msg, attachments: { text: attachment })
    ExceptionNotifier.notify_exception(exception)
  end
end
