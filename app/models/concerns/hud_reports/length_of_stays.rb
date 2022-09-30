###
# Copyright 2016 - 2022 Green River Data Analysis, LLC
#
# License detail: https://github.com/greenriver/hmis-warehouse/blob/production/LICENSE.md
###

# Required concerns:
#   HudReports:Households for HoH
#
# Required accessors:
#   a_t: Arel Type for the universe model
#   enrollment_scope: ServiceHistoryEnrollment scope for the enrollments included in the report
#   report_end_date: end date for report
#
# Required universe fields:
#   last_date_in_program: Date
#   length_of_stay: Integer
#   destination: Integer (HUD destination codes)
#   project_type: Integer (HUD project type codes)
#
module HudReports::LengthOfStays
  extend ActiveSupport::Concern

  included do
    private def stayers_clause
      a_t[:last_date_in_program].eq(nil).or(a_t[:last_date_in_program].gt(report_end_date))
    end

    private def leavers_clause
      a_t[:last_date_in_program].lteq(report_end_date)
    end

    # Heads of households and adult stayers in the project 365 days or more (Row 16)
    # should include any adult stayer present when the head of household’s stay is 365 days or more,
    # even if that adult has not been in the household that long.
    private def hoh_lts_stayer_ids
      @hoh_lts_stayer_ids ||= universe.members.where(
        hoh_clause.
          and(a_t[:length_of_stay].gteq(365)).
          and(stayers_clause),
      ).pluck(:head_of_household_id)
    end

    private def hoh_exit_dates
      @hoh_exit_dates ||= universe.members.where(hoh_clause).pluck(a_t[:head_of_household_id], a_t[:last_date_in_program]).to_h
    end

    private def hoh_entry_dates
      @hoh_entry_dates ||= {}.tap do |entries|
        enrollment_scope.where(client_id: client_scope).heads_of_households.
          find_each do |enrollment|
          entries[enrollment[:head_of_household_id]] ||= enrollment.first_date_in_program
        end
      end
    end

    private def hoh_move_in_dates
      @hoh_move_in_dates ||= {}.tap do |entries|
        enrollment_scope.where(client_id: client_scope).heads_of_households.
          find_each do |enrollment|
          entries[enrollment[:head_of_household_id]] ||= enrollment.move_in_date
        end
      end
    end

    private def hoh_date_to_street_dates
      @hoh_date_to_street_dates ||= {}.tap do |entries|
        enrollment_scope.where(client_id: client_scope).heads_of_households.
          find_each do |enrollment|
          entries[enrollment[:head_of_household_id]] ||= enrollment.enrollment.DateToStreetESSH
        end
      end
    end

    # Given the reporting period, how long has the client been in the enrollment
    private def stay_length(enrollment)
      end_date = [
        enrollment.last_date_in_program,
        report_end_date,
      ].compact.min
      days = (end_date - enrollment.first_date_in_program).to_i
      # no bed night on last day of residential service, but yes service on non-residential projects
      days += 1 unless enrollment.computed_project_type.in?(GrdaWarehouse::Hud::Project::RESIDENTIAL_PROJECT_TYPE_IDS)
      days
    end

    private def bed_nights(enrollment)
      enrollment.bed_nights(end_date: report_end_date)
    end

    private def time_to_move_in(enrollment)
      move_in_date = appropriate_move_in_date(enrollment)
      return nil unless move_in_date.present?

      (move_in_date - enrollment.first_date_in_program).to_i
    end

    private def date_to_street(enrollment, reporting_age)
      return hoh_date_to_street_dates[enrollment[:head_of_household_id]] if reporting_age.present? && reporting_age <= 17

      enrollment.enrollment.DateToStreetESSH
    end

    private def approximate_time_to_move_in(enrollment, reporting_age)
      move_in_date = if enrollment.computed_project_type.in?(GrdaWarehouse::Hud::Project::RESIDENTIAL_PROJECT_TYPES[:ph])
        appropriate_move_in_date(enrollment) || enrollment.first_date_in_program
      else
        enrollment.first_date_in_program
      end
      # DateToStreetESSH needs to be pulled from HoH if not available on client
      # This applies to any household member whose age is <= 17 (calculated according to the HMIS Reporting Glossary), regardless of their relationship to the head of household, but not clients of unknown age.
      dts = date_to_street(enrollment, reporting_age)
      return nil if dts.blank? || dts > move_in_date

      (move_in_date - dts).to_i
    end

    # Household members already in the household when the head of household moves into housing have the same [housing move-in date] as the head of household. For household members joining the household after it is already in housing, use the person’s [project start date] as their [housing move-in date].
    private def appropriate_move_in_date(enrollment)
      # Use the move-in-date if provided
      move_in_date = enrollment.move_in_date
      return move_in_date if move_in_date.present?

      hoh_move_in_date = hoh_entry_dates[enrollment[:head_of_household_id]]
      return nil unless hoh_move_in_date.present?
      return hoh_move_in_date if enrollment.first_date_in_program < hoh_move_in_date

      enrollment.first_date_in_program
    end

    private def lengths
      {
        '0 to 7 days' => a_t[:bed_nights].between(0..7),
        '8 to 14 days' => a_t[:bed_nights].between(8..14),
        '15 to 21 days' => a_t[:bed_nights].between(15..21),
        '22 to 30 days' => a_t[:bed_nights].between(22..30),
        '30 days or less' => a_t[:bed_nights].lteq(30),
        '31 to 60 days' => a_t[:bed_nights].between(31..60),
        '61 to 90 days' => a_t[:bed_nights].between(61..90),
        '61 to 180 days' => a_t[:bed_nights].between(61..180),
        '91 to 180 days' => a_t[:bed_nights].between(91..180),
        '181 to 365 days' => a_t[:bed_nights].between(181..365),
        '366 to 730 days (1-2 Yrs)' => a_t[:bed_nights].between(366..730),
        '731 to 1,095 days (2-3 Yrs)' => a_t[:bed_nights].between(731..1_095),
        '731 days or more' => a_t[:bed_nights].gteq(731),
        '1,096 to 1,460 days (3-4 Yrs)' => a_t[:bed_nights].between(1_096..1_460),
        '1,461 to 1,825 days (4-5 Yrs)' => a_t[:bed_nights].between(1_461..1_825),
        'More than 1,825 days (> 5 Yrs)' => a_t[:bed_nights].gteq(1_825),
        'Data Not Collected' => a_t[:bed_nights].eq(nil),
        'Total' => Arel.sql('1=1'),
      }.freeze
    end
  end
end
