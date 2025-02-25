###
# Copyright 2016 - 2023 Green River Data Analysis, LLC
#
# License detail: https://github.com/greenriver/hmis-warehouse/blob/production/LICENSE.md
###

# frozen_string_literal: true

module Types
  class HmisSchema::Enrollment < Types::BaseObject
    include Types::HmisSchema::HasEvents
    include Types::HmisSchema::HasServices
    include Types::HmisSchema::HasAssessments
    include Types::HmisSchema::HasCeAssessments
    include Types::HmisSchema::HasFiles
    include Types::HmisSchema::HasIncomeBenefits
    include Types::HmisSchema::HasDisabilities
    include Types::HmisSchema::HasHealthAndDvs
    include Types::HmisSchema::HasYouthEducationStatuses
    include Types::HmisSchema::HasEmploymentEducations
    include Types::HmisSchema::HasCurrentLivingSituations
    include Types::HmisSchema::HasCustomDataElements

    def self.configuration
      Hmis::Hud::Enrollment.hmis_configuration(version: '2022')
    end

    available_filter_options do
      arg :status, [HmisSchema::Enums::EnrollmentFilterOptionStatus]
      arg :open_on_date, GraphQL::Types::ISO8601Date
      arg :project_type, [Types::HmisSchema::Enums::ProjectType]
      arg :search_term, String
    end

    description 'HUD Enrollment'
    field :id, ID, null: false
    field :project, Types::HmisSchema::Project, null: false
    hud_field :entry_date
    field :exit_date, GraphQL::Types::ISO8601Date, null: true
    field :exit_destination, Types::HmisSchema::Enums::Hud::Destination, null: true
    field :status, HmisSchema::Enums::EnrollmentStatus, null: false
    assessments_field
    events_field
    services_field filter_args: { omit: [:project, :project_type], type_name: 'ServicesForEnrollment' }
    files_field
    ce_assessments_field
    income_benefits_field
    disabilities_field
    health_and_dvs_field
    youth_education_statuses_field
    employment_educations_field
    current_living_situations_field
    field :household_id, ID, null: false
    field :household_short_id, ID, null: false
    field :household, HmisSchema::Household, null: false
    field :household_size, Integer, null: false
    field :client, HmisSchema::Client, null: false
    # 3.15.1
    hud_field :relationship_to_ho_h, HmisSchema::Enums::Hud::RelationshipToHoH, null: false
    # 3.16.1
    field :enrollment_coc, String, null: true
    # 3.08
    hud_field :disabling_condition, HmisSchema::Enums::Hud::NoYesReasonsForMissingData
    # 3.13.1
    field :date_of_engagement, GraphQL::Types::ISO8601Date, null: true
    # 3.20.1
    field :move_in_date, GraphQL::Types::ISO8601Date, null: true
    # 3.917
    field :living_situation, HmisSchema::Enums::Hud::LivingSituation
    # TODO(2024) enable 3.917.A
    # hud_field :rental_subsidy_type, Types::HmisSchema::Enums::Hud::RentalSubsidyType
    hud_field :length_of_stay, HmisSchema::Enums::Hud::ResidencePriorLengthOfStay
    hud_field :los_under_threshold, HmisSchema::Enums::Hud::NoYesMissing
    hud_field :previous_street_essh, HmisSchema::Enums::Hud::NoYesMissing
    hud_field :date_to_street_essh
    hud_field :times_homeless_past_three_years, HmisSchema::Enums::Hud::TimesHomelessPastThreeYears
    hud_field :months_homeless_past_three_years, HmisSchema::Enums::Hud::MonthsHomelessPastThreeYears
    # P3
    field :date_of_path_status, GraphQL::Types::ISO8601Date, null: true
    field :client_enrolled_in_path, HmisSchema::Enums::Hud::NoYesMissing, null: true
    field :reason_not_enrolled, HmisSchema::Enums::Hud::ReasonNotEnrolled, null: true
    # V4
    field :percent_ami, HmisSchema::Enums::Hud::PercentAMI, null: true
    # R1
    field :referral_source, HmisSchema::Enums::Hud::ReferralSource, null: true
    field :count_outreach_referral_approaches, Integer, null: true
    # R2
    field :date_of_bcp_status, GraphQL::Types::ISO8601Date, null: true
    field :eligible_for_rhy, HmisSchema::Enums::Hud::NoYesMissing, null: true
    field :reason_no_services, HmisSchema::Enums::Hud::ReasonNoServices, null: true
    field :runaway_youth, HmisSchema::Enums::Hud::NoYesReasonsForMissingData, null: true
    # R3
    field :sexual_orientation, HmisSchema::Enums::Hud::SexualOrientation, null: true
    field :sexual_orientation_other, String, null: true
    # R11
    field :former_ward_child_welfare, HmisSchema::Enums::Hud::NoYesReasonsForMissingData, null: true
    field :child_welfare_years, HmisSchema::Enums::Hud::RHYNumberofYears, null: true
    field :child_welfare_months, Integer, null: true
    # R12
    field :former_ward_juvenile_justice, HmisSchema::Enums::Hud::NoYesReasonsForMissingData, null: true
    field :juvenile_justice_years, HmisSchema::Enums::Hud::RHYNumberofYears, null: true
    field :juvenile_justice_months, Integer, null: true
    # R13
    field :unemployment_fam, HmisSchema::Enums::Hud::NoYesMissing, null: true
    field :mental_health_disorder_fam, HmisSchema::Enums::Hud::NoYesMissing, null: true
    field :physical_disability_fam, HmisSchema::Enums::Hud::NoYesMissing, null: true
    field :alcohol_drug_use_disorder_fam, HmisSchema::Enums::Hud::NoYesMissing, null: true
    field :insufficient_income, HmisSchema::Enums::Hud::NoYesMissing, null: true
    field :incarcerated_parent, HmisSchema::Enums::Hud::NoYesMissing, null: true
    # V6
    field :vamc_station, HmisSchema::Enums::Hud::VamcStationNumber, null: true
    # V7
    field :target_screen_reqd, HmisSchema::Enums::Hud::NoYesMissing, null: true
    field :time_to_housing_loss, HmisSchema::Enums::Hud::TimeToHousingLoss, null: true
    field :annual_percent_ami, HmisSchema::Enums::Hud::AnnualPercentAMI, null: true
    field :literal_homeless_history, HmisSchema::Enums::Hud::LiteralHomelessHistory, null: true
    field :client_leaseholder, HmisSchema::Enums::Hud::NoYesMissing, null: true
    field :hoh_leaseholder, HmisSchema::Enums::Hud::NoYesMissing, null: true
    field :subsidy_at_risk, HmisSchema::Enums::Hud::NoYesMissing, null: true
    field :eviction_history, HmisSchema::Enums::Hud::EvictionHistory, null: true
    field :criminal_record, HmisSchema::Enums::Hud::NoYesMissing, null: true
    field :incarcerated_adult, HmisSchema::Enums::Hud::IncarceratedAdult, null: true
    field :prison_discharge, HmisSchema::Enums::Hud::NoYesMissing, null: true
    field :sex_offender, HmisSchema::Enums::Hud::NoYesMissing, null: true
    field :disabled_hoh, HmisSchema::Enums::Hud::NoYesMissing, null: true
    field :current_pregnant, HmisSchema::Enums::Hud::NoYesMissing, null: true
    field :single_parent, HmisSchema::Enums::Hud::NoYesMissing, null: true
    field :dependent_under6, HmisSchema::Enums::Hud::DependentUnder6, null: true
    field :hh5_plus, HmisSchema::Enums::Hud::NoYesMissing, null: true
    field :coc_prioritized, HmisSchema::Enums::Hud::NoYesMissing, null: true
    field :hp_screening_score, HmisSchema::Enums::Hud::NoYesMissing, null: true
    field :threshold_score, HmisSchema::Enums::Hud::NoYesMissing, null: true
    # TODO(2024): C4 with preferred language list
    # field :translation_needed, HmisSchema::Enums::Hud::NoYesReasonsForMissingData, null: true
    # field :preferred_language, Integer, null: true
    # field :preferred_language_different, String, null: true

    field :in_progress, Boolean, null: false
    hud_field :date_updated
    hud_field :date_created
    hud_field :date_deleted
    field :user, HmisSchema::User, null: true
    field :intake_assessment, HmisSchema::Assessment, null: true
    field :exit_assessment, HmisSchema::Assessment, null: true
    access_field do
      can :edit_enrollments
      can :delete_enrollments
    end
    custom_data_elements_field

    field :current_unit, HmisSchema::Unit, null: true

    field :reminders, [HmisSchema::Reminder], null: false

    field :open_enrollment_summary, [HmisSchema::EnrollmentSummary], null: false

    def open_enrollment_summary
      return [] unless current_user.can_view_open_enrollment_summary_for?(object)

      client = load_ar_association(object, :client)
      load_ar_association(client, :enrollments).where.not(id: object.id).open_including_wip
    end

    def reminders
      # assumption is this is called on a single record; we aren't solving n+1 queries
      project = object.project
      enrollments = project.enrollments_including_wip.where(household_id: object.HouseholdID)
      Hmis::Reminders::ReminderGenerator.perform(project: project, enrollments: enrollments)
    end

    def project
      if object.in_progress?
        wip = load_ar_association(object, :wip)
        load_ar_association(wip, :project)
      else
        load_ar_association(object, :project)
      end
    end

    def exit_date
      exit&.exit_date
    end

    def exit_destination
      exit&.destination
    end

    def exit
      load_ar_association(object, :exit)
    end

    # TODO(2024): remove once 2024 enrollmentcoc column is added
    def enrollment_coc
      object.enrollment_cocs.first&.coc_code
    end

    def status
      Types::HmisSchema::Enums::EnrollmentStatus.from_enrollment(object)
    end

    def client
      load_ar_association(object, :client)
    end

    def household_short_id
      Hmis::Hud::Household.short_id(object.household_id)
    end

    def household
      load_ar_association(object, :household)
    end

    def household_size
      load_ar_association(household, :enrollments).size
    end

    def in_progress
      object.in_progress?
    end

    def events(**args)
      resolve_events(**args)
    end

    def services(**args)
      resolve_services(**args)
    end

    def assessments(**args)
      resolve_assessments(**args)
    end

    def ce_assessments(**args)
      resolve_ce_assessments(**args)
    end

    def files(**args)
      resolve_files(**args)
    end

    def income_benefits(**args)
      resolve_income_benefits(**args)
    end

    def disabilities(**args)
      resolve_disabilities(**args)
    end

    def disability_groups(**args)
      resolve_disability_groups(**args)
    end

    def health_and_dvs(**args)
      resolve_health_and_dvs(**args)
    end

    def user
      load_ar_association(object, :user)
    end

    def current_unit
      load_ar_association(object, :current_unit)
    end
  end
end
