require 'rails_helper'
require 'models/exporters/hmis_six_one_one/project_setup'
require 'models/exporters/hmis_six_one_one/single_project_tests'
require 'models/exporters/hmis_six_one_one/enrollment_setup'
require 'models/exporters/hmis_six_one_one/single_enrollment_tests'

def project_test_type
  'organization-based'
end

RSpec.describe Exporters::HmisSixOneOne::Base, type: :model do
  include_context 'project setup'
  include_context 'enrollment setup'

  let(:project_test_type) { 'organization-based' }
  let(:exporter) do
    Exporters::HmisSixOneOne::Base.new(
      start_date: 1.week.ago.to_date,
      end_date: Date.current,
      projects: organizations.first.projects.map(&:id),
      period_type: 3,
      directive: 3,
      user_id: user.id,
    )
  end

  include_context 'single-project tests'
  include_context 'single-enrollment tests'
end
