###
# Copyright 2016 - 2020 Green River Data Analysis, LLC
#
# License detail: https://github.com/greenriver/hmis-warehouse/blob/master/LICENSE.md
###

# Assumptions:
# The import is authoritative for the date range specified in the Export.csv file
# The import is authoritative for the projects specified in the Project.csv file
# There's no reason to have client records with no enrollments
# All tables that hang off a client also hang off enrollments

# reload!; importer = HmisCsvTwentyTwenty::Importer::Importer.new(loader_id: 2, data_source_id: 14, debug: true); importer.import!

module HmisCsvTwentyTwenty::Importer
  class Importer
    include TsqlImport
    include NotifierConfig
    include HmisTwentyTwenty
    include ActionView::Helpers::DateHelper

    attr_accessor :logger, :notifier_config, :import, :range, :data_source, :importer_log

    SELECT_BATCH_SIZE = 10_000
    INSERT_BATCH_SIZE = 2_000

    def initialize(
      loader_id:,
      data_source_id:,
      logger: Rails.logger,
      debug: true,
      deidentified: false
    )
      setup_notifier('HMIS CSV Importer 2020')
      @loader_log = HmisCsvTwentyTwenty::Loader::LoaderLog.find(loader_id.to_i)
      @data_source = GrdaWarehouse::DataSource.find(data_source_id.to_i)
      @logger = logger
      @debug = debug

      @deidentified = deidentified
      self.importer_log = setup_import
      importable_files.each_key do |file_name|
        setup_summary(file_name)
      end
      log('De-identifying clients') if @deidentified
      log('Limiting to white-listed projects') if @project_whitelist
    end

    def self.module_scope
      'HmisCsvTwentyTwenty::Importer'
    end

    def self.look_aside_scope
      'HmisCsvTwentyTwenty::Aggregated'
    end

    def import!
      return if already_running_for_data_source?

      GrdaWarehouse::DataSource.with_advisory_lock("hud_import_#{data_source.id}") do
        start_import
        pre_process!
        validate_data_set!
        aggregate!
        ingest!
        complete_import
      end
    end

    # Move all data from the data lake to either the structured, or aggregated tables
    def pre_process!
      importer_log.update(status: :pre_processing)

      # Enable look asides for aggregated classes
      importable_files.each_value do |klass|
        HmisTwentyTwenty.look_aside(klass) if aggregators_from_class(klass, @data_source).present?
      end

      # TODO: This could be parallelized
      importable_files.each do |file_name, klass|
        log("Pre-processing #{klass.name}")
        pre_process_class!(file_name, klass)
      end
    end

    def pre_process_class!(file_name, klass)
      batch = []
      failures = []
      source_data_scope_for(file_name).find_each(batch_size: SELECT_BATCH_SIZE) do |source|
        destination = klass.new_from(source, deidentified: @deidentified)
        destination.importer_log_id = importer_log.id
        destination.pre_processed_at = Time.current
        destination.set_source_hash
        row_failures = destination.run_row_validations(file_name, importer_log)
        failures += row_failures
        # Don't insert any where we have actual errors
        batch << destination unless validation_failures_contain_errors?(row_failures)
        if batch.count == INSERT_BATCH_SIZE
          process_batch!(klass, batch, file_name, type: 'pre_processed')
          batch = []
          importer_log.save
        end
        if failures.count == INSERT_BATCH_SIZE
          HmisCsvValidation::Base.import(failures.compact)
          failures = []
        end
      end

      process_batch!(klass, batch, file_name, type: 'pre_processed') if batch.present? # ensure we get the last batch
      HmisCsvValidation::Base.import(failures.compact) if failures.present?
      importer_log.save
    end

    private def validation_failures_contain_errors?(failures)
      failures.any?(&:skip_row?)
    end

    def aggregate!
      importer_log.update(status: :aggregating)

      # TODO: This could be parallelized
      importable_files.each_value do |klass|
        aggregators = aggregators_from_class(klass, @data_source)
        next unless aggregators.present?

        log("Aggregating #{klass.name}")
        aggregators.each { |a| a.aggregate!(@importer_log) }
        HmisTwentyTwenty.look_aside(klass)
      end
    end

    def validate_data_set!
      # TODO: Apply whole table validations
      importable_files.each do |filename, klass|
        failures = klass.run_complex_validations!(importer_log, filename)
        HmisCsvValidation::Base.import(failures) if failures.any?
      end
    end

    # Pass 0, Walk the tree starting from projects and mark all as dead (in date range where appropriate)
    # Pass 1, create any where hud-key isn't in warehouse in same data source and involved projects
    # Pass 2, pluck previous hash and DateUpdated from warehouse, joining on involved scope
    #   If hash is the same, mark as live
    #   If hash differs
    #     if the incoming DateUpdated is older, mark warehouse as live
    #     If the incoming DateUpdated is the same or newer, update warehouse from lake,
    #       mark client demographics dirty
    #       mark enrollment dirty
    #       if exit record changes also mark associated enrollment dirty
    #       mark warehouse live
    # Delete all marked as dead for data source
    # For any enrollments where history_generated_on is blank? || history_generated_on < Exit.ExitDate run equivalent of:
    # GrdaWarehouse::Tasks::ServiceHistory::Enrollment.batch_process_date_range!(range)
    # In here, add history_generated_on date to enrollment record
    def ingest!
      # Ingestion should not use the look-aside tables
      HmisTwentyTwenty.clear_look_aside

      # Mark everything that exists in the warehouse, that would be covered by this import
      # as pending deletion.  We'll remove the pending where appropriate
      mark_tree_as_dead(Date.current)

      # Add any records we don't have
      add_new_data

      # Process existing records,
      # determine which records have changed and are newer
      process_existing

      # Sweep all remaining items in a pending delete state
      remove_pending_deletes

      # Update the effective export end date of the export
      export_klass = importable_file_class('Export').reflect_on_association(:destination_record).klass
      export_klass.last.update(effective_export_end_date: (importable_files.except('Export.csv').map do |_, klass|
        klass.where(importer_log_id: @importer_log.id).maximum(:DateUpdated)
      end.compact + ['1900-01-01'.to_date]).max)
    end

    def aggregators_from_class(klass, data_source)
      basename = klass.name.split('::').last
      data_source.import_aggregators[basename]&.map(&:constantize)
    end

    def mark_tree_as_dead(pending_date_deleted)
      importable_files.each_value do |klass|
        klass.mark_tree_as_dead(
          data_source_id: data_source.id,
          project_ids: involved_project_ids,
          date_range: date_range,
          pending_date_deleted: pending_date_deleted,
        )
      end
    end

    def add_new_data
      importable_files.each do |file_name, klass|
        log("Adding new #{klass.name}")
        destination_class = klass.reflect_on_association(:destination_record).klass
        batch = []
        klass.new_data(
          data_source_id: data_source.id,
          project_ids: involved_project_ids,
          date_range: date_range,
          importer_log_id: importer_log.id,
        ).find_each(batch_size: SELECT_BATCH_SIZE) do |row|
          batch << row.as_destination_record
          if batch.count == INSERT_BATCH_SIZE
            process_batch!(destination_class, batch, file_name, type: 'added')
            batch = []
          end
        end

        process_batch!(destination_class, batch, file_name, type: 'added') if batch.present? # ensure we get the last batch
        log("Added #{summary_for(file_name, 'added')} new #{klass.name}")
      end
    end

    def process_existing
      # TODO: This could be parallelized
      importable_files.each do |file_name, klass|
        mark_unchanged(klass, file_name)
        mark_incoming_older(klass, file_name)
        apply_updates(klass, file_name)
      end
    end

    def remove_pending_deletes
      importable_files.each do |file_name, klass|
        # Never delete Exports
        next if klass.hud_key == :ExportID

        # Never delete Projects, Organizations, or Clients, but cleanup any pending deletions
        if klass.hud_key.in?([:ProjectID, :OrganizationID, :PersonalID])
          klass.existing_destination_data(data_source_id: data_source.id, project_ids: involved_project_ids, date_range: date_range).update_all(pending_date_deleted: nil)
        else
          delete_count = klass.existing_destination_data(data_source_id: data_source.id, project_ids: involved_project_ids, date_range: date_range).update_all(pending_date_deleted: nil, DateDeleted: Time.current)
          note_processed(file_name, delete_count, 'removed')
        end
      end
    end

    def involved_project_ids
      @involved_project_ids ||= HmisCsvTwentyTwenty::Importer::Project.
        where(importer_log_id: importer_log.id).
        pluck(:ProjectID)
    end

    # At this point,
    #   * All new data has been added
    #   * All extraneous data has been deleted
    #   * All unchanged data has been marked as live
    #   * All existing data currently marked as delete pending, should be updated from the incoming data
    # apply updates will:
    #   Mark client demographics dirty
    #   Mark enrollment dirty, for Enrollment and Exit tables
    #   Mark warehouse live
    private def apply_updates(klass, file_name)
      # Exports are always inserts, never updates
      return if klass.hud_key == :ExportID

      log("Updating #{klass.name}")

      existing = klass.existing_destination_data(
        data_source_id: data_source.id,
        project_ids: involved_project_ids,
        date_range: date_range,
      ).pluck(klass.hud_key)
      destination_class = klass.reflect_on_association(:destination_record).klass
      batch = []
      existing.each_slice(SELECT_BATCH_SIZE) do |hud_keys|
        klass.where(
          importer_log_id: @importer_log.id,
          klass.hud_key => hud_keys,
        ).find_each(batch_size: SELECT_BATCH_SIZE) do |source|
          destination = source.as_destination_record
          destination.pending_date_deleted = nil
          case klass.hud_key
          when :PersonalID
            destination.demographic_dirty = true
          when :EnrollmentID
            destination.processed_as = nil
          when :ExitID
            # These are tracked separately so we can bulk update them at the end
            track_dirty_enrollment(destination.EnrollmentID)
          end
          batch << destination
          if batch.count == INSERT_BATCH_SIZE
            # Client model doesn't have a uniqueness constraint because of the warehouse data source
            # so these must be processed more slowly
            if klass.hud_key == :PersonalID
              batch.each do |incoming|
                destination_class.where(
                  data_source_id: incoming.data_source_id,
                  PersonalID: incoming.PersonalID,
                ).update_all(incoming.slice(klass.upsert_column_names(version: '2020')))
              end
            else
              destination_class.import(
                batch,
                on_duplicate_key_update: {
                  conflict_target: destination_class.conflict_target,
                  columns: destination_class.upsert_column_names(version: '2020'),
                },
              )
            end
            note_processed(file_name, batch.count, 'updated')
            batch = []
          end
        end
      end
      if batch.present? # ensure we get the last batch
        if klass.hud_key == :PersonalID
          batch.each do |incoming|
            destination_class.where(
              data_source_id: incoming.data_source_id,
              PersonalID: incoming.PersonalID,
            ).update_all(incoming.slice(klass.upsert_column_names(version: '2020')))
          end
        else
          destination_class.import(
            batch,
            on_duplicate_key_update: {
              conflict_target: destination_class.conflict_target,
              columns: destination_class.upsert_column_names(version: '2020'),
            },
          )
        end
        note_processed(file_name, batch.count, 'updated')
      end

      # If we tracked any dirty enrollments, we can mark them all dirty now
      if klass.hud_key == :ExitID
        GrdaWarehouse::Hud::Enrollment.where(data_source_id: data_source.id, EnrollmentID: dirty_enrollment_ids).
          update_all(processed_as: nil)
      end
      log("Updated #{summary_for(file_name, 'updated')} existing #{klass.name}")
    end

    private def mark_unchanged(klass, file_name)
      # We always bring over Exports
      return if klass.hud_key == :ExportID

      existing = klass.existing_destination_data(
        data_source_id: data_source.id,
        project_ids: involved_project_ids,
        date_range: date_range,
      ).where.not(DateUpdated: nil). # A bad import can sometimes cause this
        pluck(klass.hud_key, :source_hash)
      incoming = klass.where(importer_log_id: @importer_log.id).
        pluck(klass.hud_key, :source_hash)
      unchanged = (existing & incoming).map(&:first)
      unchanged.each_slice(INSERT_BATCH_SIZE) do |batch|
        klass.warehouse_class.where(
          data_source_id: data_source.id,
          klass.hud_key => batch,
        ).update_all(pending_date_deleted: nil)
        note_processed(file_name, batch.count, 'unchanged')
      end
    end

    private def mark_incoming_older(klass, file_name)
      # Doesn't apply to Exports
      return if klass.hud_key == :ExportID

      existing = klass.existing_destination_data(
        data_source_id: data_source.id,
        project_ids: involved_project_ids,
        date_range: date_range,
      ).pluck(klass.hud_key, :DateUpdated).to_h
      incoming = klass.where(importer_log_id: @importer_log.id).
        pluck(klass.hud_key, :DateUpdated).to_h

      # ignore any where we don't have a DateUpdated,
      # or we don't have a matching incoming record
      existing.reject! { |k, v| v.blank? || incoming[k].blank? }

      # if the incoming DateUpdated is strictly less than the existing one
      # trust the warehouse is correct
      unchanged = existing.select { |k, v| incoming[k] < v }.keys
      unchanged.each_slice(INSERT_BATCH_SIZE) do |batch|
        klass.warehouse_class.where(
          data_source_id: data_source.id,
          klass.hud_key => batch,
        ).update_all(pending_date_deleted: nil)
        note_processed(file_name, batch.count, 'unchanged')
      end
    end

    private def track_dirty_enrollment(enrollment_id)
      @track_dirty_enrollment ||= Set.new
      @track_dirty_enrollment << enrollment_id
    end

    private def dirty_enrollment_ids
      @track_dirty_enrollment
    end

    private def process_batch!(klass, batch, file_name, type:)
      errors = []
      klass.import(batch)
      note_processed(file_name, batch.count, type)
      rescue StandardError => e
        batch.each do |row|
          row.save!
          note_processed(file_name, 1, type)
        rescue StandardError => e
          errors << add_error(file: file_name, klass: klass, source_id: row.source_id, message: e.message)
        end
        @importer_log.import_errors.import(errors)
    end

    private def bulk_update!(klass, batch, file_name, type:)
      errors = []
      klass.import(batch, on_duplicate_key_update:
        {
          conflict_target: klass.conflict_target,
          columns: klass.upsert_column_names(version: '2020'),
        })
      note_processed(file_name, batch.count, type)
    rescue StandardError => e
      batch.each do |row|
        klass.import([row], on_duplicate_key_update:
          {
            conflict_target: klass.conflict_target,
            columns: klass.upsert_column_names(version: '2020'),
          })
        note_processed(file_name, 1, type)
      rescue StandardError => e
        errors << add_error(file: file_name, klass: klass, source_id: row.source_id, message: e.message)
      end
      @importer_log.import_errors.import(errors)
    end

    private def source_data_scope_for(file_name)
      @loaded_files ||= @loader_log.class.importable_files
      @loaded_files[file_name].unscoped.where(loader_id: @loader_log.id)
    end

    private def date_range
      @date_range ||= Filters::DateRange.new(
        start: export_record.ExportStartDate.to_date,
        end: export_record.ExportEndDate.to_date,
      )
    end

    private def export_record
      @export_record ||= HmisCsvTwentyTwenty::Importer::Export.find_by(importer_log_id: importer_log.id)
    end

    def already_running_for_data_source?
      running = GrdaWarehouse::DataSource.advisory_lock_exists?("hud_import_#{data_source.id}")
      logger.warn "Import of Data Source: #{data_source.short_name} already running...exiting" if running
      running
    end

    def complete_import
      data_source.update(last_imported_at: Time.zone.now)
      importer_log.completed_at = Time.zone.now
      importer_log.upload_id = @upload.id if @upload.present?
      importer_log.save
      elapsed = Time.current - @started_at
      log("Import Completed in #{distance_of_time_in_words(elapsed)}")
    end

    def note_processed(file, line_count, type)
      importer_log.summary[file][type] += line_count
    end

    def summary_for(file, type)
      importer_log.summary[file][type]
    end

    def setup_summary(file)
      importer_log.summary ||= {}
      importer_log.summary[file] ||= {
        'pre_processed' => 0,
        'added' => 0,
        'updated' => 0,
        'unchanged' => 0,
        'removed' => 0,
        'total_errors' => 0,
      }
    end

    def importable_files
      self.class.importable_files
    end

    def importable_file_class(name)
      self.class.importable_file_class(name)
    end

    def self.soft_deletable_sources
      importable_files_map.except('Export.csv').values.map { |name| "GrdaWarehouse::Hud::#{name}".constantize }
    end

    def setup_import
      importer_log = HmisCsvTwentyTwenty::Importer::ImporterLog.new
      importer_log.created_at = Time.now
      importer_log.data_source = data_source
      importer_log.summary = {}
      importer_log.save
      importer_log
    end

    def start_import
      importer_log.update(status: :started)
      @loader_log.update(importer_log_id: importer_log.id)
      @started_at = Time.current
    end

    def log(message)
      @notifier&.ping message
      logger.info message if @debug
    end

    def add_error(file:, klass:, source_id:, message:)
      importer_log.summary[file]['total_errors'] += 1
      log(message)
      importer_log.import_errors.build(
        source_type: klass,
        source_id: source_id,
        message: "Error importing #{klass}",
        details: message,
      )
    end
  end
end
