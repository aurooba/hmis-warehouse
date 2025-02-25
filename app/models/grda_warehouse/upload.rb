###
# Copyright 2016 - 2023 Green River Data Analysis, LLC
#
# License detail: https://github.com/greenriver/hmis-warehouse/blob/production/LICENSE.md
###

module GrdaWarehouse
  class Upload < GrdaWarehouseBase
    require 'csv'
    include ActionView::Helpers::DateHelper
    acts_as_paranoid

    belongs_to :data_source, class_name: 'GrdaWarehouse::DataSource'
    belongs_to :user, optional: true

    belongs_to :delayed_job, optional: true, class_name: '::Delayed::Job'
    has_one :import_log, class_name: 'GrdaWarehouse::ImportLog', required: false

    has_one_attached :hmis_zip
    validates :data_source, presence: true
    validates :hmis_zip, presence: true, on: :create

    scope :completed, -> do
      where(percent_complete: 100)
    end

    scope :unprocessed_s3_migration, -> do
      # plucking these seems to be 100x faster than where.not(id: migrated)
      migrated = ActiveStorage::Attachment.where(record_type: 'GrdaWarehouse::Upload').pluck(:record_id)
      all = pluck(:id)
      unmigrated = all - migrated
      return none if unmigrated.blank?

      where(id: unmigrated)
    end

    scope :viewable_by, ->(user) do
      where(data_source_id: GrdaWarehouse::DataSource.directly_viewable_by(user).select(:id))
    end

    def has_import_log? # rubocop:disable Naming/PredicateName
      @has_import_log ||= GrdaWarehouse::ImportLog.where.not(completed_at: nil).
        where(data_source_id: data_source_id, completed_at: completed_at).
        exists?
    end

    def import_log_id
      return nil unless has_import_log?

      GrdaWarehouse::ImportLog.where.not(completed_at: nil).
        where(data_source_id: data_source_id, completed_at: completed_at).pluck(:id).first
    end

    def status
      if percent_complete.zero?
        'Queued'
      elsif percent_complete == 0.01
        'Started'
      elsif percent_complete == 100
        'Complete'
      else
        percent_complete
      end
    end

    def import_time(details: false)
      if delayed_job.present?
        return "Failed with: #{delayed_job.last_error.split("\n").first}" if delayed_job.last_error.present? && details
        return 'failed' if delayed_job.failed_at.present? || delayed_job.last_error.present?
      end
      if percent_complete == 100
        begin
          seconds = ((completed_at - created_at) / 1.minute).round * 60
          "#{distance_of_time_in_words(seconds)} -#{created_at.strftime('%l:%M %P')} to #{completed_at.strftime('%l:%M %P')}"
        rescue Exception
          'unknown'
        end
      else
        if updated_at < 2.days.ago # rubocop:disable Style/IfInsideElse
          'failed'
        else
          'processing...'
        end
      end
    end

    def copy_to_s3!
      return unless content.present?
      return unless valid? # Ignore uploads that are already invalid (data source deleted?)
      return if hmis_zip.attached? # don't re-process

      puts "Migrating #{file} to S3"

      Tempfile.create(binmode: true) do |tmp_file|
        tmp_file.write(content)
        tmp_file.rewind
        hmis_zip.attach(io: tmp_file, content_type: content_type, filename: file, identify: false)
      end
    end

    # Overrides some methods, so must be included at the end
    include RailsDrivers::Extensions
  end
end
