###
# Copyright 2016 - 2023 Green River Data Analysis, LLC
#
# License detail: https://github.com/greenriver/hmis-warehouse/blob/production/LICENSE.md
###

module PerformanceDashboard::Overview::Entering::Veteran
  extend ActiveSupport::Concern

  # NOTE: always count the most-recently started enrollment within the range
  def entering_by_veteran
    @entering_by_veteran ||= Rails.cache.fetch([self.class.name, cache_slug, __method__], expires_in: 5.minutes) do
      buckets = veteran_buckets.map { |b| [b, []] }.to_h
      counted = {}
      entering.
        joins(:client).
        order(first_date_in_program: :desc).
        pluck(:client_id, c_t[:VeteranStatus], :first_date_in_program).each do |id, veteran_status, _|
          counted[veteran_bucket(veteran_status)] ||= Set.new
          buckets[veteran_bucket(veteran_status)] << id unless counted[veteran_bucket(veteran_status)].include?(id)
          counted[veteran_bucket(veteran_status)] << id
        end
      buckets
    end
  end

  def entering_by_veteran_data_for_chart
    @entering_by_veteran_data_for_chart ||= begin
      columns = [@filter.date_range_words]
      columns += entering_by_veteran.values.map(&:count)
      categories = entering_by_veteran.keys
      filter_selected_data_for_chart(
        {
          labels: categories.map { |s| [s, HudUtility.veteran_status(s)] }.to_h,
          chosen: @veteran_statuses,
          columns: columns,
          categories: categories,
        },
      )
    end
  end

  private def entering_by_veteran_details(options)
    sub_key = options[:sub_key]&.to_i
    ids = if sub_key
      entering_by_veteran[sub_key]
    else
      entering_by_veteran.values.flatten
    end
    details = entries_current_period.joins(:client).
      where(client_id: ids).
      order(she_t[:first_date_in_program].desc)
    details = details.where(veteran_query(sub_key)) if sub_key
    details.pluck(*detail_columns(options).values).
      index_by(&:first)
  end
end
