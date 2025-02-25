###
# Copyright 2016 - 2023 Green River Data Analysis, LLC
#
# License detail: https://github.com/greenriver/hmis-warehouse/blob/production/LICENSE.md
###

module
  CoreDemographicsReport::EthnicityCalculations
  extend ActiveSupport::Concern
  included do
    def ethnicity_detail_hash
      {}.tap do |hashes|
        HudUtility.ethnicities.each do |key, title|
          hashes["ethnicity_#{key}"] = {
            title: "Ethnicity - #{title}",
            headers: client_headers,
            columns: client_columns,
            scope: -> { report_scope.joins(:client, :enrollment).where(client_id: client_ids_in_ethnicity(key)).distinct },
          }
        end
      end
    end

    def ethnicity_count(type)
      mask_small_population(ethnicity_breakdowns[type]&.count&.presence || 0)
    end

    def ethnicity_percentage(type)
      total_count = mask_small_population(client_ethnicities.count)
      return 0 if total_count.zero?

      of_type = ethnicity_count(type)
      return 0 if of_type.zero?

      ((of_type.to_f / total_count) * 100)
    end

    def ethnicity_data_for_export(rows)
      rows['_Ethnicity Break'] ||= []
      rows['*Ethnicity'] ||= []
      rows['*Ethnicity'] += ['Ethnicity', nil, 'Count', 'Percentage', nil]
      ::HudUtility.ethnicities.each do |id, title|
        rows["_Ethnicity_data_#{title}"] ||= []
        rows["_Ethnicity_data_#{title}"] += [
          title,
          nil,
          ethnicity_count(id),
          ethnicity_percentage(id) / 100,
        ]
      end
      rows
    end

    def client_ids_in_ethnicity(key)
      ethnicity_breakdowns[key]&.map(&:first)
    end

    private def ethnicity_breakdowns
      @ethnicity_breakdowns ||= client_ethnicities.group_by do |_, v|
        v
      end
    end

    private def client_ethnicities
      @client_ethnicities ||= Rails.cache.fetch([self.class.name, cache_slug, __method__], expires_in: expiration_length) do
        {}.tap do |clients|
          report_scope.joins(:client).order(first_date_in_program: :desc).
            distinct.
            pluck(:client_id, c_t[:Ethnicity], :first_date_in_program).
            each do |client_id, ethnicity, _|
              clients[client_id] ||= ethnicity
            end
        end
      end
    end
  end
end
