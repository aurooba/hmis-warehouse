###
# Copyright 2016 - 2023 Green River Data Analysis, LLC
#
# License detail: https://github.com/greenriver/hmis-warehouse/blob/production/LICENSE.md
###

module CePerformance
  class Results::TimeToAssessmentAverage < CePerformance::Result
    include CePerformance::Results::Calculations
    # For anyone served by CE, how long before assessment
    def self.calculate(report, period)
      values = client_scope(report, period).pluck(:days_before_assessment)
      create(
        report_id: report.id,
        period: period,
        value: average(values),
      )
    end

    def self.client_scope(report, period)
      report.clients.served_in_period(period).
        where.not(days_before_assessment: nil)
    end

    def self.title
      _('Average Length of time from Access to Assessment')
    end

    def description
      'Average number of days between CE Project Start Date and CE Assessment date.'
    end

    def self.calculation
      'Average number of days between CE Project Start Date and CE Assessment date.'
    end

    def self.category
      'Time'
    end

    def unit
      'days'
    end

    def nested_header
      'Median Time'
    end

    def nested_results
      [
        CePerformance::Results::TimeToAssessmentMedian,
      ]
    end

    def detail_link_text
      "Average: #{value.to_i} days"
    end

    def indicator(comparison)
      @indicator ||= OpenStruct.new(
        primary_value: value.to_i,
        primary_unit: unit,
        secondary_value: percent_change_over_year(comparison).to_i,
        secondary_unit: '%',
        value_label: 'change over year',
        passed: passed?(comparison),
        direction: direction(comparison),
      )
    end

    def data_for_chart(report, comparison)
      aprs = report.ce_aprs.order(start_date: :asc).to_a
      comparison_year = aprs.first.end_date.year
      report_year = aprs.last.end_date.year
      columns = [
        ['x', comparison_year, report_year],
        [unit, comparison.value, value],
      ]

      {
        x: 'x',
        columns: columns,
        type: 'bar',
        labels: {
          colors: 'white',
          centered: true,
        },
      }
    end
  end
end
