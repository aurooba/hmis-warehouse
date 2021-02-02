require 'rails_helper'
require 'models/exporters/hmis_twenty_twenty/project_setup'
require 'models/exporters/hmis_twenty_twenty/enrollment_setup'
require 'models/exporters/hmis_twenty_twenty/single_enrollment_tests'

RSpec.describe Exporters::HmisTwentyTwenty::Base, type: :model do
  include_context '2020 project setup'
  include_context '2020 enrollment setup'

  let(:exporter) do
    Exporters::HmisTwentyTwenty::Base.new(
      start_date: 1.week.ago.to_date,
      end_date: Date.current,
      projects: [projects.first.id],
      period_type: 3,
      directive: 3,
      user_id: user.id,
    )
  end

  include_context '2020 single-enrollment tests'
end
