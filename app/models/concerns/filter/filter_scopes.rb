###
# Copyright 2016 - 2023 Green River Data Analysis, LLC
#
# License detail: https://github.com/greenriver/hmis-warehouse/blob/production/LICENSE.md
###

module Filter::FilterScopes
  extend ActiveSupport::Concern
  included do
    private def filter_for_user_access(scope)
      scope.joins(:project).
        merge(GrdaWarehouse::Hud::Project.viewable_by(@filter.user))
    end

    private def filter_for_range(scope)
      scope = scope.open_between(start_date: @filter.start_date, end_date: @filter.end_date)
      return scope unless @filter.require_service_during_range

      scope.with_service_between(start_date: @filter.start_date, end_date: @filter.end_date)
    end

    private def filter_for_cocs(scope)
      return scope unless @filter.coc_codes.present?

      scope = filter_for_project_cocs(scope)
      filter_for_enrollment_cocs(scope)
    end

    private def filter_for_project_cocs(scope)
      scope.joins(project: :project_cocs).
        merge(GrdaWarehouse::Hud::ProjectCoc.in_coc(coc_code: @filter.coc_codes))
    end

    private def filter_for_enrollment_cocs(scope)
      scope.left_outer_joins(enrollment: :enrollment_coc_at_entry).
        # limit enrollment coc to the cocs chosen, and any random thing that's not a valid coc
        merge(
          GrdaWarehouse::Hud::EnrollmentCoc.where(CoCCode: @filter.coc_codes).
          or(GrdaWarehouse::Hud::EnrollmentCoc.where(CoCCode: nil)).
          or(GrdaWarehouse::Hud::EnrollmentCoc.where.not(CoCCode: HudUtility.cocs.keys)),
        )
    end

    private def filter_for_coc(scope)
      return scope unless @filter.coc_code.present?

      scope.joins(project: :project_cocs).
        merge(GrdaWarehouse::Hud::ProjectCoc.in_coc(coc_code: @filter.coc_code))
    end

    private def filter_for_household_type(scope)
      return scope unless @filter.household_type.present? && @filter.household_type != :all

      case @filter.household_type
      when :without_children
        scope.adult_only_households
      when :with_children
        scope.adults_with_children
      when :only_children
        scope.child_only_households
      end
    end

    private def filter_for_head_of_household(scope)
      return scope unless @filter.hoh_only

      scope.where(she_t[:head_of_household].eq(true))
    end

    private def age_calculation
      age_on_date(@filter.start_date)
    end

    private def filter_for_age(scope)
      return scope unless @filter.age_ranges.present? && (@filter.available_age_ranges.values & @filter.age_ranges).present?

      # Or'ing ages is very slow, instead we'll build up an acceptable
      # array of ages
      ages = []
      ages += Filters::FilterBase.age_range(:zero_to_four).to_a if @filter.age_ranges.include?(:zero_to_four)
      ages += Filters::FilterBase.age_range(:five_to_ten).to_a if @filter.age_ranges.include?(:five_to_ten)
      ages += Filters::FilterBase.age_range(:eleven_to_fourteen).to_a if @filter.age_ranges.include?(:eleven_to_fourteen)
      ages += Filters::FilterBase.age_range(:fifteen_to_seventeen).to_a if @filter.age_ranges.include?(:fifteen_to_seventeen)
      ages += Filters::FilterBase.age_range(:under_eighteen).to_a if @filter.age_ranges.include?(:under_eighteen)
      ages += Filters::FilterBase.age_range(:eighteen_to_twenty_four).to_a if @filter.age_ranges.include?(:eighteen_to_twenty_four)
      ages += Filters::FilterBase.age_range(:twenty_five_to_twenty_nine).to_a if @filter.age_ranges.include?(:twenty_five_to_twenty_nine)
      ages += Filters::FilterBase.age_range(:thirty_to_thirty_four).to_a if @filter.age_ranges.include?(:thirty_to_thirty_four)
      ages += Filters::FilterBase.age_range(:thirty_five_to_thirty_nine).to_a if @filter.age_ranges.include?(:thirty_five_to_thirty_nine)
      ages += Filters::FilterBase.age_range(:thirty_to_thirty_nine).to_a if @filter.age_ranges.include?(:thirty_to_thirty_nine)
      ages += Filters::FilterBase.age_range(:forty_to_forty_four).to_a if @filter.age_ranges.include?(:forty_to_forty_four)
      ages += Filters::FilterBase.age_range(:forty_five_to_forty_nine).to_a if @filter.age_ranges.include?(:forty_five_to_forty_nine)
      ages += Filters::FilterBase.age_range(:forty_to_forty_nine).to_a if @filter.age_ranges.include?(:forty_to_forty_nine)
      ages += Filters::FilterBase.age_range(:fifty_to_fifty_four).to_a if @filter.age_ranges.include?(:fifty_to_fifty_four)
      ages += Filters::FilterBase.age_range(:fifty_five_to_fifty_nine).to_a if @filter.age_ranges.include?(:fifty_five_to_fifty_nine)
      ages += Filters::FilterBase.age_range(:sixty_to_sixty_one).to_a if @filter.age_ranges.include?(:sixty_to_sixty_one)
      ages += Filters::FilterBase.age_range(:sixty_two_to_sixty_four).to_a if @filter.age_ranges.include?(:sixty_two_to_sixty_four)
      ages += Filters::FilterBase.age_range(:over_sixty_one).to_a if @filter.age_ranges.include?(:over_sixty_one)
      ages += Filters::FilterBase.age_range(:over_sixty_four).to_a if @filter.age_ranges.include?(:over_sixty_four)

      scope.joins(:client).where(age_calculation.in(ages))
    end

    private def filter_for_gender(scope)
      return scope unless @filter.genders.present?

      scope = scope.joins(:client)
      gender_scope = nil
      @filter.genders.each do |value|
        column = HudUtility.gender_id_to_field_name[value]
        next unless column

        gender_query = report_scope_source.joins(:client).where(c_t[column.to_sym].eq(HudUtility.gender_comparison_value(value)))
        gender_scope = add_alternative(gender_scope, gender_query)
      end
      scope.merge(gender_scope)
    end

    private def filter_for_race(scope)
      return scope unless @filter.races.present?

      race_scope = nil
      @filter.races.each do |column|
        next if column == 'MultiRacial'

        race_scope = add_alternative(race_scope, race_alternative(column.to_sym))
      end

      # Include anyone who has more than one race listed, anded with any previous alternatives
      race_scope ||= scope
      race_scope = race_scope.where(id: multi_racial_clients.select(:id)) if @filter.races.include?('MultiRacial')
      scope.merge(race_scope)
    end

    private def multi_racial_clients
      # Looking at all races with responses of 1, where we have a sum > 1
      columns = [
        c_t[:AmIndAKNative],
        c_t[:Asian],
        c_t[:BlackAfAmerican],
        c_t[:NativeHIPacific],
        c_t[:White],
      ]
      report_scope_source.joins(:client).
        where(Arel.sql(columns.map(&:to_sql).join(' + ')).between(2..98))
    end

    private def add_alternative(scope, alternative)
      if scope.nil?
        alternative
      else
        scope.or(alternative)
      end
    end

    private def race_alternative(key)
      report_scope_source.joins(:client).where(c_t[key].eq(1))
    end

    private def filter_for_ethnicity(scope)
      return scope unless @filter.ethnicities.present?

      scope.joins(:client).where(c_t[:Ethnicity].in(@filter.ethnicities))
    end

    private def filter_for_veteran_status(scope)
      return scope unless @filter.veteran_statuses.present?

      scope.joins(:client).where(c_t[:VeteranStatus].in(@filter.veteran_statuses))
    end

    private def filter_for_project_type(scope, all_project_types: nil)
      return scope if all_project_types

      # Make this backwards compatible with a pre-set set of project_types.
      p_types = @project_types.presence || @filter.project_type_ids
      p_types += GrdaWarehouse::Hud::Project::PERFORMANCE_REPORTING[:ca] if @filter.coordinated_assessment_living_situation_homeless || @filter.ce_cls_as_homeless

      return scope if p_types.empty?

      scope.in_project_type(p_types)
    end

    private def filter_for_projects(scope)
      return scope if @filter.project_ids.blank? && @filter.project_group_ids.blank?

      project_ids = if @filter.user.report_filter_visible?(:project_ids)
        @filter.project_ids || []
      else
        []
      end
      project_groups = GrdaWarehouse::ProjectGroup.where(id: @filter.project_group_ids)
      project_groups.each do |group|
        project_ids += group.projects.pluck(:id)
      end

      return scope if project_ids.blank?

      scope.in_project(project_ids.uniq).merge(GrdaWarehouse::Hud::Project.viewable_by(@filter.user))
    end

    private def filter_for_projects_hud(scope)
      return scope.none if @filter.project_ids.blank?

      scope.in_project(@filter.project_ids).merge(GrdaWarehouse::Hud::Project.viewable_by(@filter.user))
    end

    private def filter_for_cohorts(scope)
      return scope if @filter.cohort_ids.blank?

      scope.on_cohort(cohort_id: @filter.cohort_ids)
    end

    private def filter_for_funders(scope)
      return scope if @filter.funder_ids.blank?
      return scope unless @filter.user.report_filter_visible?(:funder_ids)

      project_ids = GrdaWarehouse::Hud::Funder.viewable_by(@filter.user).
        where(Funder: @filter.funder_ids).
        joins(:project).
        select(p_t[:id])
      scope.in_project(project_ids)
    end

    private def filter_for_data_sources(scope)
      return scope if @filter.data_source_ids.blank?
      return scope unless @filter.user.report_filter_visible?(:data_source_ids)

      scope.in_data_source(@filter.data_source_ids).joins(:data_source).merge(GrdaWarehouse::DataSource.viewable_by(@filter.user))
    end

    private def filter_for_organizations(scope)
      return scope if @filter.organization_ids.blank?
      return scope unless @filter.user.report_filter_visible?(:organization_ids)

      scope.in_organization(@filter.organization_ids).merge(GrdaWarehouse::Hud::Organization.viewable_by(@filter.user))
    end

    private def filter_for_sub_population(scope)
      return scope unless @filter.sub_population.present?

      scope.public_send(@filter.sub_population)
    end

    private def filter_for_prior_living_situation(scope)
      return scope if @filter.prior_living_situation_ids.blank?

      scope.where(housing_status_at_entry: @filter.prior_living_situation_ids)
    end

    private def filter_for_destination(scope)
      return scope if @filter.destination_ids.blank?

      scope.where(destination: @filter.destination_ids)
    end

    private def filter_for_disabilities(scope)
      return scope if @filter.disabilities.blank?

      scope.joins(enrollment: :disabilities).
        merge(
          GrdaWarehouse::Hud::Disability.where(
            InformationDate: @filter.range,
            DisabilityType: @filter.disabilities,
            DisabilityResponse: GrdaWarehouse::Hud::Disability.positive_responses,
          ),
        )
    end

    private def filter_for_indefinite_disabilities(scope)
      return scope if @filter.indefinite_disabilities.blank?

      scope.joins(enrollment: :disabilities).
        merge(
          GrdaWarehouse::Hud::Disability.where(
            InformationDate: @filter.range,
            IndefiniteAndImpairs: @filter.indefinite_disabilities,
          ),
        )
    end

    private def filter_for_dv_status(scope)
      return scope if @filter.dv_status.blank?

      scope.joins(enrollment: :health_and_dvs).
        merge(
          GrdaWarehouse::Hud::HealthAndDv.where(
            InformationDate: @filter.range,
            DomesticViolenceVictim: @filter.dv_status,
          ),
        )
    end

    private def filter_for_dv_currently_fleeing(scope)
      return scope if @filter.currently_fleeing.blank?

      scope.joins(enrollment: :health_and_dvs).
        merge(
          GrdaWarehouse::Hud::HealthAndDv.where(
            InformationDate: @filter.range,
            CurrentlyFleeing: @filter.currently_fleeing,
          ),
        )
    end

    private def filter_for_chronic_at_entry(scope)
      return scope unless @filter.chronic_status

      scope.joins(enrollment: :ch_enrollment).
        merge(GrdaWarehouse::ChEnrollment.chronically_homeless)
    end

    private def filter_for_chronic_status(scope)
      return scope unless @filter.chronic_status

      chronic_source = case GrdaWarehouse::Config.get(:chronic_definition).to_sym
      when :chronics
        GrdaWarehouse::Chronic
      when :hud_chronics
        GrdaWarehouse::HudChronic
      end
      max_date = chronic_source.where(date: @filter.range).maximum(:date)

      scope.where(client_id: chronic_source.where(date: max_date).select(:client_id))
    end

    private def filter_for_rrh_move_in(scope)
      return scope unless @filter.rrh_move_in

      scope.in_project_type(13).where(move_in_date: @filter.range)
    end

    private def filter_for_psh_move_in(scope)
      return scope unless @filter.psh_move_in

      scope.in_project_type(3).where(move_in_date: @filter.range)
    end

    private def filter_for_active_roi(scope)
      return scope unless @filter.active_roi

      scope.joins(:client).merge(GrdaWarehouse::Hud::Client.consent_form_valid)
    end

    private def filter_for_first_time_homeless_in_past_two_years(scope)
      return scope unless @filter.first_time_homeless

      visible_enrollments = filter_for_user_access(scope)
      # Homeless enrollments open the two years prior to the report start
      recent_homeless_enrollments = visible_enrollments.
        homeless.
        open_between(start_date: @filter.start - 2.years, end_date: @filter.start)
      # For a given client, only include rows where they don't have an open homeless
      # enrollment in the 2 years prior to the report start date
      scope.homeless.where.not(client_id: recent_homeless_enrollments.select(:client_id))
    end

    private def filter_for_returned_to_homelessness_from_permanent_destination(scope)
      return scope unless @filter.returned_to_homelessness_from_permanent_destination

      visible_enrollments = filter_for_user_access(scope)
      exits = visible_enrollments.
        select(:id, :client_id, :last_date_in_program, :destination).
        joins(enrollment: :exit).
        ended_between(start_date: @filter.start - 2.years, end_date: @filter.start).
        define_window(:client_window).
        partition_by(:client_id, order_by: { last_date_in_program: :desc }).
        select_window(:row_number, over: :client_window, as: :row_id)
      client_ids_with_recent_permanent_exits = GrdaWarehouse::ServiceHistoryEnrollment.from(exits).
        where("row_id = 1 and destination in (#{HudUtility.permanent_destinations.join(', ')})")

      scope.homeless.where(client_id: client_ids_with_recent_permanent_exits.select(:client_id))
    end

    # This needs to work correctly with project type filters, where it adds the
    # potentially additional type of CA, but only if LivingSituation (3.917.1) is
    # of a homeless type (6, 1, 18)
    private def filter_for_ca_homeless(scope)
      return scope unless @filter.coordinated_assessment_living_situation_homeless

      p_types = @project_types.presence || @filter.project_type_ids
      scope.joins(:enrollment).where(
        she_t[:computed_project_type].in(GrdaWarehouse::Hud::Project::PERFORMANCE_REPORTING[:ca]).
        and(e_t[:LivingSituation].in(HudUtility.homeless_situations(as: :prior))).
        or(she_t[:computed_project_type].in(p_types)),
      )
    end

    private def filter_for_ce_cls_homeless(scope)
      return scope unless @filter.ce_cls_as_homeless

      client_ids_with_two_homeless_cls = scope.ca.joins(enrollment: :current_living_situations).
        merge(GrdaWarehouse::Hud::CurrentLivingSituation.homeless.between(start_date: @filter.start_date, end_date: @filter.end_date)).group(she_t[:client_id]).
        having(nf('COUNT', [she_t[:client_id]]).gt(1)).
        select(:client_id)
      p_types = @project_types.presence || @filter.project_type_ids
      scope.where(client_id: client_ids_with_two_homeless_cls).
        or(scope.where(computed_project_type: p_types))
    end

    private def filter_for_times_homeless(scope)
      return scope unless @filter.times_homeless_in_last_three_years.present?

      scope.joins(:enrollment).where(e_t[:TimesHomelessPastThreeYears].in(@filter.times_homeless_in_last_three_years))
    end
  end
end
