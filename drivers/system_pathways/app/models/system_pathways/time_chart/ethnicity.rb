###
# Copyright 2016 - 2022 Green River Data Analysis, LLC
#
# License detail: https:#//github.com/greenriver/hmis-warehouse/blob/production/LICENSE.md
###

module SystemPathways::TimeChart::Ethnicity
  extend ActiveSupport::Concern

  private def ethnicity_chart_data
    {
      chart: 'ethnicity',
      config: {
        size: {
          height: 2400,
        },
      },
      data: ethnicity_data,
      table: as_table(ethnicity_table_data, ['Project Type'] + ethnicities.values),
      link_params: {
        columns: [[]] + ethnicities.keys.map { |k| ['details[ethnicities][]', k] },
        rows: [[]] + detail_node_keys.map { |k| ['node', k] },
      },
    }
  end

  private def ethnicity_table_data
    ethnicity_counts[:ph_counts].transform_keys { |k| ph_projects[k] }
    flat_counts = ethnicity_counts[:project_type_counts].merge(ethnicity_counts[:ph_counts])
    flat_counts['Returned to Homelessness'] = ethnicity_counts[:return_counts]
    flat_counts
  end

  def ethnicity_counts
    @ethnicity_counts ||= {}.tap do |e_counts|
      e_counts[:project_type_counts] = project_type_node_names.map do |label|
        data = {}
        ethnicities.each_key do |k|
          data[k] ||= 0
        end
        data.merge!(node_clients(label).group(:ethnicity).average(sp_e_t[:stay_length]).transform_values(&:round))

        [
          label,
          data,
        ]
      end.to_h
      e_counts[:ph_counts] = ph_projects.map do |p_type, p_label|
        data = {}
        ethnicities.each_key do |k|
          data[k] ||= 0
        end
        data.merge!(node_clients(p_type).group(:ethnicity).average(sp_e_t[:days_to_move_in]).transform_values(&:round))
        [
          p_label,
          data,
        ]
      end.to_h
      data = {}
      ethnicities.each_key do |k|
        data[k] ||= 0
      end
      data.merge!(node_clients('Served by Homeless System').
        group(:ethnicity).
        where(sp_c_t[:days_to_return].not_eq(nil)).
        average(sp_c_t[:days_to_return]).transform_values(&:round))

      e_counts[:return_counts] = data
    end
  end

  private def ethnicity_data
    @ethnicity_data ||= {}.tap do |data|
      data['x'] = 'x'
      data['type'] = 'bar'
      data['colors'] = {}
      data['labels'] = { 'colors' => {}, 'centered' => true }
      data['columns'] = [['x', *time_groups]]
      all_zero = {}
      ['x', *time_groups].each do |g|
        all_zero[g] = true
      end
      all_zero['x'] = false
      project_type_counts = ethnicity_counts[:project_type_counts]
      ph_counts = ethnicity_counts[:ph_counts]
      return_counts = ethnicity_counts[:return_counts]

      ethnicities.each.with_index do |(k, ethnicity), i|
        row = [ethnicity]
        # Time in project
        project_type_node_names.each do |label|
          count = project_type_counts[label][k]

          color = config.color_for('ethnicity', i)
          bg_color = color.background_color
          data['colors'][ethnicity] = bg_color
          data['labels']['colors'][ethnicity] = color.calculated_foreground_color(bg_color)
          row << count
        end
        # Time before move-in
        ph_projects.each_value do |p_label|
          count = ph_counts[p_label][k]
          color = config.color_for('ethnicity', i)
          bg_color = color.background_color
          data['colors'][ethnicity] = bg_color
          data['labels']['colors'][ethnicity] = color.calculated_foreground_color(bg_color)
          row << count
        end
        count = return_counts[k]
        color = config.color_for('ethnicity', i)
        bg_color = color.background_color
        data['colors'][ethnicity] = bg_color
        data['labels']['colors'][ethnicity] = color.calculated_foreground_color(bg_color)
        row << count
        data['columns'] << row
      end
      data['columns'] = remove_all_zero_rows(data['columns'])
    end
  end
end
