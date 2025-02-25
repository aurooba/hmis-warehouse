###
# Copyright 2016 - 2023 Green River Data Analysis, LLC
#
# License detail: https://github.com/greenriver/hmis-warehouse/blob/production/LICENSE.md
###

module HmisDataQualityTool
  class Client < ::HudReports::ReportClientBase
    self.table_name = 'hmis_dqt_clients'
    include ArelHelper
    include DqConcern
    acts_as_paranoid
    attr_accessor :enrollments

    has_many :hud_reports_universe_members, inverse_of: :universe_membership, class_name: 'HudReports::UniverseMember', foreign_key: :universe_membership_id
    belongs_to :client, class_name: 'GrdaWarehouse::Hud::Client', optional: true

    def self.detail_headers
      {
        destination_client_id: { title: 'Warehouse Client ID' },
        first_name: { title: 'First Name' },
        last_name: { title: 'Last Name' },
        name_data_quality: { title: 'Name Data Quality', translator: ->(v) { "#{HudUtility.name_data_quality(v)} (#{v})" } },
        personal_id: { title: 'HMIS Personal ID' },
        dob: { title: 'DOB' },
        dob_data_quality: { title: 'DOB Data Quality', translator: ->(v) { "#{HudUtility.dob_data_quality(v)} (#{v})" } },
        male: { title: 'Male', translator: ->(v) { "#{HudUtility.no_yes_missing(v)} (#{v})" } },
        female: { title: 'Female', translator: ->(v) { "#{HudUtility.no_yes_missing(v)} (#{v})" } },
        no_single_gender: { title: 'No Single Gender', translator: ->(v) { "#{HudUtility.no_yes_missing(v)} (#{v})" } },
        transgender: { title: 'Transgender', translator: ->(v) { "#{HudUtility.no_yes_missing(v)} (#{v})" } },
        questioning: { title: 'Questioning', translator: ->(v) { "#{HudUtility.no_yes_missing(v)} (#{v})" } },
        gender_none: { title: 'Gender None', translator: ->(v) { "#{HudUtility.gender_none(v)} (#{v})" } },
        am_ind_ak_native: { title: 'American Indian, Alaska Native, or Indigenous', translator: ->(v) { "#{HudUtility.no_yes_missing(v&.to_i)} (#{v})" } },
        asian: { title: 'Asian or Asian American', translator: ->(v) { "#{HudUtility.no_yes_missing(v&.to_i)} (#{v})" } },
        black_af_american: { title: 'Black, African American, or African', translator: ->(v) { "#{HudUtility.no_yes_missing(v&.to_i)} (#{v})" } },
        native_hi_pacific: { title: 'Native Hawaiian or Pacific Islander', translator: ->(v) { "#{HudUtility.no_yes_missing(v&.to_i)} (#{v})" } },
        white: { title: 'White', translator: ->(v) { "#{HudUtility.no_yes_missing(v&.to_i)} (#{v})" } },
        race_none: { title: 'Race None', translator: ->(v) { "#{HudUtility.race_none(v)} (#{v})" } },
        ethnicity: { title: 'Ethnicity', translator: ->(v) { "#{HudUtility.ethnicity(v)} (#{v})" } },
        veteran_status: { title: 'Veteran Status', translator: ->(v) { "#{HudUtility.no_yes_reasons_for_missing_data(v)} (#{v})" } },
        ssn: { title: 'SSN', translator: ->(v) { masked_ssn(v) } },
        ssn_data_quality: { title: 'SSN Data Quality', translator: ->(v) { "#{HudUtility.ssn_data_quality(v)} (#{v})" } },
        overlapping_entry_exit: { title: 'Overlapping Entry/Exit enrollments in ES, SH, and TH' },
        overlapping_nbn: { title: 'Overlapping Night-by-Night ES enrollments with other ES, SH, and TH' },
        overlapping_pre_move_in: { title: 'Overlapping Homeless Service After Move-in in PH' },
        overlapping_post_move_in: { title: 'Overlapping Moved-in PH' },
        ch_at_most_recent_entry: { title: 'Chronically Homeless at Most-Recent Entry' },
        ch_at_any_entry: { title: 'Chronically Homeless at Any Entry' },
      }.freeze
    end

    def self.masked_ssn(number)
      # pad with leading 0s if we don't have enough characters
      number = number.to_s.rjust(9, '0') if number.present?
      number.to_s.gsub(/(\d{3})[^\d]?(\d{2})[^\d]?(\d{4})/, 'XXX-XX-\3')
    end

    def self.detail_headers_for_export
      return detail_headers if GrdaWarehouse::Config.get(:include_pii_in_detail_downloads)

      detail_headers.except(:first_name, :last_name, :dob, :ssn)
    end

    def self.detail_headers_for(slug, report, export:)
      header_source = if export
        detail_headers_for_export
      else
        detail_headers
      end
      headers = header_source.transform_values { |v| v.except(:translator) }
      section = sections(report)[slug.to_sym]
      columns = if section.present?
        section[:detail_columns]
      else
        # Handle CH details
        columns = [
          :destination_client_id,
          :first_name,
          :last_name,
          :personal_id,
          :ch_at_most_recent_entry,
          :ch_at_any_entry,
        ]
      end
      return headers unless columns.present?

      headers.select { |k, _| k.in?(columns) }
    end

    # Because multiple of these calculations require inspecting all client enrollments
    # we're going to loop over the entire client scope once rather than
    # load it multiple times
    def self.calculate(report_items:, report:)
      destinations_counted = {}
      # We need to obey visibility restrictions on the source clients
      all_source_client_ids = report.report_scope.joins(client: :warehouse_client_destination).
        pluck(wc_t[:source_id])
      visible_source_client_ids = GrdaWarehouse::Hud::Client.source_visible_to(
        report.user,
        client_ids: all_source_client_ids,
      ).pluck(:id).to_set
      client_ids_at_chosen_projects = GrdaWarehouse::Hud::Enrollment.joins(:project, :client).
        merge(GrdaWarehouse::Hud::Project.where(id: report.filter.effective_project_ids)).
        pluck(c_t[:id]).to_set
      client_scope(report).find_in_batches do |batch|
        intermediate = {}
        batch.each do |client|
          client.source_clients.each do |sc|
            next unless visible_source_client_ids.include?(sc.id)
            next unless client_ids_at_chosen_projects.include?(sc.id)

            item = report_item_fields_from_client(
              report_items: report_items,
              destination_client: client,
              source_client: sc,
              report: report,
            )
            sections(report).each do |_, calc|
              section_title = calc[:title]
              # Only count client's once in the overlapping sections so we don't balloon the counts
              destinations_counted[section_title] ||= Set.new
              next if calc[:count_once] && destinations_counted[section_title].include?(client.id)

              destinations_counted[section_title] << client.id if calc[:count_once]

              intermediate[section_title] ||= { denominator: {}, invalid: {} }
              intermediate[section_title][:denominator][sc] = item if calc[:denominator].call(item)
              intermediate[section_title][:invalid][sc] = item if calc[:limiter].call(item)
            end
          end
        end
        intermediate.each do |section_title, item_batch|
          import_intermediate!(item_batch[:denominator].values)
          report.universe("#{section_title}__denominator").add_universe_members(item_batch[:denominator]) if item_batch[:denominator].present?
          report.universe("#{section_title}__invalid").add_universe_members(item_batch[:invalid]) if item_batch[:invalid].present?

          report_items.merge!(item_batch)
        end
      end
      report_items
    end

    def self.client_scope(report)
      GrdaWarehouse::Hud::Client.joins(source_enrollments: [:service_history_enrollment, :project]).
        preload(:warehouse_client_source, :source_clients, source_enrollments: [:exit, :project]).
        merge(report.report_scope).distinct
    end

    def self.report_item_fields_from_client(report_items:, destination_client:, source_client:, report:)
      # we only need to do the calculations once, the values will be the same for any source client,
      # no matter how many times we see it
      report_item = report_items[source_client]
      return report_item if report_item.present?

      report_item = new(
        report_id: report.id,
        client_id: source_client.id,
        destination_client_id: destination_client.id, # to actually identify overlaps, we need to work against destination clients
      )
      report_item.first_name = source_client.FirstName
      report_item.last_name = source_client.LastName
      report_item.name_data_quality = source_client.NameDataQuality
      report_item.dob = source_client.DOB
      report_item.dob_data_quality = source_client.DOBDataQuality
      # for simplicity, since we don't have a specific enrollment, calculate age as of the end of the reporting period
      report_item.reporting_age = source_client.age_on(report.filter.end)
      report_item.personal_id = source_client.PersonalID
      report_item.data_source_id = source_client.data_source_id
      report_item.male = source_client.Male
      report_item.female = source_client.Female
      report_item.no_single_gender = source_client.NoSingleGender
      report_item.transgender = source_client.Transgender
      report_item.questioning = source_client.Questioning
      report_item.gender_none = source_client.GenderNone
      report_item.am_ind_ak_native = source_client.AmIndAKNative
      report_item.asian = source_client.Asian
      report_item.black_af_american = source_client.BlackAfAmerican
      report_item.native_hi_pacific = source_client.NativeHIPacific
      report_item.white = source_client.White
      report_item.race_none = source_client.RaceNone
      report_item.ethnicity = source_client.Ethnicity
      report_item.veteran_status = source_client.VeteranStatus
      report_item.ssn = source_client.SSN
      report_item.ssn_data_quality = source_client.SSNDataQuality
      # we need these for calculations, but don't want to store them permanently,
      # also, limit them to those that overlap the projects included and the date range of the report
      report_item.enrollments = destination_client.source_enrollments.select do |en|
        # sometimes this loads source enrollments that are missing a project
        en.open_during_range?(report.filter.range) && en.project&.id&.in?(report.filter.effective_project_ids)
      end.uniq
      report_item.overlapping_entry_exit = overlapping_entry_exit(enrollments: report_item.enrollments, report: report)
      report_item.overlapping_nbn = overlapping_nbn(enrollments: report_item.enrollments, report: report)
      # NOTE: this is incorrectly named, this is homeless overlapping PH post move-in
      report_item.overlapping_pre_move_in = overlapping_homeless_post_move_in(enrollments: report_item.enrollments, report: report)
      report_item.overlapping_post_move_in = overlapping_post_move_in(enrollments: report_item.enrollments, report: report)
      report_item.ch_at_most_recent_entry = report_item.enrollments&.max_by(&:EntryDate)&.chronically_homeless_at_start?
      report_item.ch_at_any_entry = report_item.enrollments.map(&:chronically_homeless_at_start?)&.any?
      report_item
    end

    # check for overlapping ES entry exit, TH, SH
    def self.overlapping_entry_exit(enrollments:, report:)
      involved_enrollments = enrollments.select do |en|
        (en.project&.es? && ! en.project&.bed_night_tracking?) || en.project&.sh? || en.project&.th?
      end

      return 0 if involved_enrollments.blank? || involved_enrollments.count == 1

      ranges_overlap(enrollments: involved_enrollments, report: report).count
    end

    # check for overlapping PH post-move-in
    def self.overlapping_post_move_in(enrollments:, report:)
      involved_enrollments = enrollments.select do |en|
        en.project&.ph?
      end

      return 0 if involved_enrollments.blank? || involved_enrollments.count == 1

      ranges_overlap(enrollments: involved_enrollments, report: report, start_date_method: :MoveInDate).count
    end

    def self.overlapping_nbn(enrollments:, report:)
      nbn_enrollments = enrollments.select do |en|
        en.project&.es? && en.project&.bed_night_tracking?
      end
      return 0 if nbn_enrollments.blank?

      involved_enrollments = enrollments.select do |en|
        en.project&.es? || en.project&.sh? || en.project&.th?
      end
      return 0 if involved_enrollments.blank?

      overlaps = Set.new
      # see if there are any dates of service within the other homeless enrollments
      nbn_enrollments.each do |nbn_en|
        involved_enrollments.each do |en|
          next if nbn_en.id == en.id

          end_date = en.exit&.ExitDate || report.filter.end
          overlaps += nbn_en.services.where(RecordType: 200, DateProvided: [en.EntryDate, end_date]).pluck(:DateProvided)
          # nbn_en.services.each do |service|
          #   overlaps << service.DateProvided if service.DateProvided.between?(en.EntryDate, end_date) && service.bed_night?
          # end
        end
      end
      overlaps.count
    end

    def self.overlapping_homeless_post_move_in(enrollments:, report:)
      homeless_enrollments = enrollments.select do |en|
        en.project&.es? || en.project&.sh? || en.project&.th?
      end
      return 0 if homeless_enrollments.blank?

      involved_enrollments = enrollments.select do |en|
        en.project&.ph?
      end
      return 0 if involved_enrollments.blank?

      homeless_dates = homeless_enrollments.map do |h_en|
        homeless_end_date = h_en.exit&.ExitDate || report.filter.end
        if h_en.project&.es? && h_en.project&.bed_night_tracking?
          h_en.services.where(RecordType: 200, DateProvided: [h_en.EntryDate, homeless_end_date]).pluck(:DateProvided)
        else
          h_en.EntryDate...homeless_end_date
        end
      end.map(&:to_a).flatten.uniq

      housed_dates = involved_enrollments.map do |en|
        # we're only looking for overlaps with housing
        next nil unless en.MoveInDate.present?

        end_date = en.exit&.ExitDate || report.filter.end
        en.MoveInDate...end_date
      end.compact.map(&:to_a).flatten.uniq

      # Return the count of dates that exist in both homeless history and housed history
      (homeless_dates & housed_dates).count
    end

    # compare each enrollment to every other one and see if there are overlaps
    def self.ranges_overlap(enrollments:, report:, start_date_method: :EntryDate)
      overlaps = Set.new
      enrollments.product(enrollments).each do |batch|
        batch.each do |en|
          start_date = en.send(start_date_method)
          # We may be checking move-in dates and may not have one.
          next unless start_date.present?

          end_date = en.exit&.ExitDate || report.filter.end
          batch.each do |en2|
            next if en.id == en2.id

            start_date2 = en2.send(start_date_method)
            # We may be checking move-in dates and may not have one.
            next unless start_date2.present?

            end_date2 = en2.exit&.ExitDate || report.filter.end
            # three dots because starting on the end date is allowed
            overlaps << [en.id, en2.id].sort if (start_date...end_date).overlaps?((start_date2...end_date2))
          end
        end
      end
      overlaps
    end

    def self.sections(_) # rubocop:disable Metrics/CyclomaticComplexity, Metrics/PerceivedComplexity
      {
        gender_issues: {
          title: 'Gender',
          description: 'Gender fields and Gender None are incompatible, or invalid gender response was recorded, or the responses are compatible, but Gender None is "Data not collected" (99)',
          required_for: 'All',
          detail_columns: [
            :destination_client_id,
            :personal_id,
            :first_name,
            :last_name,
            :reporting_age,
            :male,
            :female,
            :no_single_gender,
            :transgender,
            :questioning,
            :gender_none,
          ],
          denominator: ->(_item) { true },
          limiter: ->(item) {
            # any fall outside accepted options
            values = [
              item.male,
              item.female,
              item.no_single_gender,
              item.transgender,
              item.questioning,
            ]
            return true if (values - HudUtility.yes_no_missing_options.keys).any?

            # any are yes and GenderNone is present and not 99
            return true if values.include?(1) && item.gender_none.present? && item.gender_none != 99

            # all are no or not collected and GenderNone is not in 8, 9
            # note: GenderNone 99 will trigger an error even though all 0s and a 99 is a valid response
            return true if values.all? { |m| m.in?([0, 99]) } && ! item.gender_none.in?([8, 9])

            false
          },
        },
        race_issues: {
          title: 'Race',
          description: 'Race fields and Race None are incompatible, or invalid race response was recorded, or the responses are compatible, but Race None is "Data not collected" (99)',
          required_for: 'All',
          detail_columns: [
            :destination_client_id,
            :personal_id,
            :first_name,
            :last_name,
            :reporting_age,
            :am_ind_ak_native,
            :asian,
            :black_af_american,
            :native_hi_pacific,
            :white,
            :race_none,
          ],
          denominator: ->(_item) { true },
          limiter: ->(item) {
            # any fall outside accepted options
            values = [
              item.am_ind_ak_native,
              item.asian,
              item.black_af_american,
              item.native_hi_pacific,
              item.white,
            ]
            return true if (values - HudUtility.yes_no_missing_options.keys).any?

            # any are yes and RaceNone is present and isn't "not collected"
            return true if values.include?(1) && item.race_none.present? && item.race_none != 99

            # all are no or not collected and RaceNone is not in 8, 9
            # note: RaceNone 99 will trigger an error even though all 0s and a 99 is a valid response
            return true if values.all? { |m| m.in?([0, 99]) } && ! item.race_none.in?([8, 9])

            false
          },
        },
        dob_issues: {
          title: 'DOB',
          description: 'DOB is blank, before Oct. 10 1910, DOB is after an entry date, or DOB Data Quality is not collected, but DOB is present',
          required_for: 'All',
          detail_columns: [
            :destination_client_id,
            :personal_id,
            :first_name,
            :last_name,
            :reporting_age,
            :dob,
            :dob_data_quality,
          ],
          denominator: ->(_item) { true },
          limiter: ->(item) {
            # DOB is Blank
            return true if item.dob.blank?
            # DOB Quality is 99 or blank but dob is present?
            return true if item.dob.present? && (item.dob_data_quality.blank? || item.dob_data_quality == 99)
            # before 10/10/1910
            return true if item.dob.present? && item.dob <= '1910-10-10'.to_date
            # in the future
            return true if item.dob >= Date.tomorrow
            # after any entry date
            return true if item.enrollments.any? { |en| en.EntryDate < item.dob }

            false
          },
        },
        ssn_issues: {
          title: 'Social Security Number',
          description: 'SSN is blank but SSN Data Quality is "Full SSN reported" (1), SSN is present but SSN Data Quality is not 1 or "Approximate or partial SSN reported" (2), or SSN Data Quality is "Data not collected" (99) or blank, or SSN is all zeros',
          required_for: 'All',
          detail_columns: [
            :destination_client_id,
            :personal_id,
            :first_name,
            :last_name,
            :reporting_age,
            :ssn,
            :ssn_data_quality,
          ],
          denominator: ->(_item) { true },
          limiter: ->(item) {
            # SSN DQ is 99
            return true if item.ssn_data_quality == 99 || item.ssn_data_quality.blank?
            # SSN is Blank, but indicated it should be there
            return true if item.ssn.blank? && item.ssn_data_quality == 1
            # SSN is present but DQ indicates it shouldn't be
            return true if item.ssn.present? && ! item.ssn_data_quality.in?([1, 2])
            # SSN all zeros
            return true if (item.ssn =~ /^0+$/).present?

            false
          },
        },
        name_issues: {
          title: 'Name',
          description: 'First or last name is blank but Name Data Quality is "Full name reported" (1), name is present but Name Data Quality is not 1 or "Partial, street name, or code name reported" (2), or Name Data Quality is "Data not collected" (99) or blank',
          required_for: 'All',
          detail_columns: [
            :destination_client_id,
            :personal_id,
            :first_name,
            :last_name,
            :reporting_age,
            :name_data_quality,
          ],
          denominator: ->(_item) { true },
          limiter: ->(item) {
            # Name DQ is 99
            return true if item.name_data_quality == 99 || item.name_data_quality.blank?
            # Name is Blank, but indicated it should be there
            return true if [item.first_name, item.last_name].any?(nil) && item.name_data_quality == 1
            # Name is present but DQ indicates it shouldn't be
            return true if [item.first_name, item.last_name].all?(&:present?) && ! item.name_data_quality.in?([1, 2])

            false
          },
        },
        ethnicity_issues: {
          title: 'Ethnicity',
          description: 'Ethnicity is "Data not collected" (99) or blank',
          required_for: 'All',
          detail_columns: [
            :destination_client_id,
            :personal_id,
            :first_name,
            :last_name,
            :reporting_age,
            :ethnicity,
          ],
          denominator: ->(_item) { true },
          limiter: ->(item) {
            return true if item.ethnicity == 99 || item.ethnicity.blank?

            false
          },
        },
        veteran_issues: {
          title: 'Veteran Status',
          description: 'Veteran Status is "Data not collected" (99) or blank for adults',
          required_for: 'Adults (as of report end)',
          detail_columns: [
            :destination_client_id,
            :personal_id,
            :first_name,
            :last_name,
            :reporting_age,
            :veteran_status,
          ],
          denominator: ->(item) { item.reporting_age.present? && item.reporting_age > 18 },
          limiter: ->(item) {
            return false if item.reporting_age.blank? || item.reporting_age < 18
            return true if item.veteran_status == 99 || item.veteran_status.blank?

            false
          },
        },
        overlapping_entry_exit_issues: {
          title: 'Overlapping Entry/Exit enrollments in ES, SH, and TH',
          description: 'Homeless projects using Entry/Exit tracking methods should not have overlapping enrollments.',
          required_for: 'All',
          count_once: true,
          detail_columns: [
            :destination_client_id,
            :personal_id,
            :first_name,
            :last_name,
            :reporting_age,
            :overlapping_entry_exit,
          ],
          denominator: ->(_item) { true },
          limiter: ->(item) {
            item.overlapping_entry_exit.positive?
          },
        },
        overlapping_nbn_issues: {
          title: 'Overlapping Night-by-Night ES enrollments with other ES, SH, and TH',
          description: 'Client\'s receiving more than two overlapping ES NbN services are included.',
          required_for: 'All',
          count_once: true,
          detail_columns: [
            :destination_client_id,
            :personal_id,
            :first_name,
            :last_name,
            :reporting_age,
            :overlapping_nbn,
          ],
          denominator: ->(_item) { true },
          limiter: ->(item) {
            item.overlapping_nbn > 1
          },
        },
        # NOTE: this is incorrectly named, this is homeless overlapping PH post move-in
        overlapping_pre_move_in_issues: {
          title: 'Overlapping Homeless Service After Move-in in PH',
          description: 'Bed nights in ES, SH or TH must not overlap with days housed in RRH, PSH or OPH. Client\'s receiving more than two overlapping homeless nights are included.',
          required_for: 'Adults',
          count_once: true,
          detail_columns: [
            :destination_client_id,
            :personal_id,
            :first_name,
            :last_name,
            :reporting_age,
            :overlapping_pre_move_in,
          ],
          denominator: ->(item) { item.reporting_age.present? && item.reporting_age > 18 },
          limiter: ->(item) {
            return false unless item.reporting_age.present? && item.reporting_age > 18

            item.overlapping_pre_move_in > 2
          },
        },
        overlapping_post_move_in_issues: {
          title: 'Overlapping Moved-in PH',
          description: 'Client\'s should not be housed in more than one project at a time.',
          required_for: 'Adults',
          count_once: true,
          detail_columns: [
            :destination_client_id,
            :personal_id,
            :first_name,
            :last_name,
            :reporting_age,
            :overlapping_post_move_in,
          ],
          denominator: ->(item) { item.reporting_age.present? && item.reporting_age > 18 },
          limiter: ->(item) {
            return false unless item.reporting_age.present? && item.reporting_age > 18

            item.overlapping_post_move_in.positive?
          },
        },
      }
    end
  end
end
