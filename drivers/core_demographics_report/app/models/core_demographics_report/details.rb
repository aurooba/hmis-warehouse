###
# Copyright 2016 - 2023 Green River Data Analysis, LLC
#
# License detail: https://github.com/greenriver/hmis-warehouse/blob/production/LICENSE.md
###

module
  CoreDemographicsReport::Details
  extend ActiveSupport::Concern
  included do
    def detail_link_base
      "#{section_subpath}details"
    end

    def section_subpath
      'core_demographics_report/warehouse_reports/shared/'
    end

    def detail_path_array
      [:details] + report_path_array
    end

    def detail_hash
      {}.merge(age_detail_hash).
        merge(gender_detail_hash).
        merge(disability_detail_hash).
        merge(ethnicity_detail_hash).
        merge(race_detail_hash).
        merge(household_detail_hash).
        merge(dv_detail_hash).
        merge(relationship_detail_hash).
        merge(prior_detail_hash).
        merge(enrollment_detail_hash)
    end

    def detail_scope_from_key(key)
      detail = detail_hash[key]
      return report_scope.none unless detail

      detail[:scope].call.distinct
    end

    def support_title(key)
      detail = detail_hash[key]

      return '' unless detail

      detail[:title]
    end

    def header_for(key)
      detail = detail_hash[key]

      return '' unless detail

      detail[:headers]
    end

    def detail_headers_for_export(key)
      return header_for(key) if GrdaWarehouse::Config.get(:include_pii_in_detail_downloads)

      header_for(key) - pii_headers
    end

    def columns_for(key)
      detail = detail_hash[key]

      return '' unless detail

      detail[:columns]
    end

    def detail_columns_for_export(key)
      return columns_for(key) if GrdaWarehouse::Config.get(:include_pii_in_detail_downloads)

      columns_for(key) - pii_columns
    end

    def detail_column_display(header:, column:)
      case header
      when 'Project Type'
        HudUtility.project_type(column)
      when 'CoC'
        HudUtility.coc_name(column)
      when 'Female', 'Male', 'No Single Gender', 'Transgender', 'Questioning', 'Unknown Gender'
        HudUtility.no_yes_reasons_for_missing_data(column)
      when 'Relationship To HoH'
        HudUtility.relationship_to_hoh(column)
      when 'Destination'
        HudUtility.destination(column)
      else
        column
      end
    end

    def client_headers
      [
        'Client ID',
        'Personal ID',
        'First Name',
        'Last Name',
        'DOB',
        'Reporting Age',
        'Relationship To HoH',
        'Female',
        'Male',
        'No Single Gender',
        'Transgender',
        'Questioning',
        'Unknown Gender',
        'Entry Date',
        'Exit Date',
        'Destination',
      ]
    end

    private def pii_headers
      [
        'First Name',
        'Last Name',
        'DOB',
      ]
    end

    private def pii_columns
      [
        c_t[:FirstName],
        c_t[:LastName],
        c_t[:DOB],
      ]
    end

    def client_columns
      [
        c_t[:id],
        e_t[:PersonalID],
        c_t[:FirstName],
        c_t[:LastName],
        c_t[:DOB],
        age_calculation,
        e_t[:RelationshipToHoH],
        c_t[:Female],
        c_t[:Male],
        c_t[:NoSingleGender],
        c_t[:Transgender],
        c_t[:Questioning],
        c_t[:GenderNone],
        e_t[:EntryDate],
        she_t[:exit_date],
        she_t[:destination],
      ]
    end
  end
end
