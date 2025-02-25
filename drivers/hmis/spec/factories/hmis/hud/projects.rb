###
# Copyright 2016 - 2023 Green River Data Analysis, LLC
#
# License detail: https://github.com/greenriver/hmis-warehouse/blob/production/LICENSE.md
###

FactoryBot.define do
  factory :hmis_hud_project, class: 'Hmis::Hud::Project' do
    data_source { association :hmis_data_source }
    user { association :hmis_hud_user, data_source: data_source }
    organization { association :hmis_hud_organization, data_source: data_source }
    sequence(:ProjectID, 200)
    DateCreated { Date.parse('2019-01-01') }
    DateUpdated { Date.parse('2019-01-01') }
    ProjectName { 'Project' }
    OperatingStartDate { Date.parse('2019-01-01') }
    ContinuumProject { 0 }
    HMISParticipatingProject { 1 }
    ProjectType { 1 }
    transient do
      funders { [] } # convenience method to set funder ids
    end
    after(:create) do |project, evaluator|
      next unless evaluator.funders.any?

      project.funders = evaluator.funders.map do |funder|
        create(:hmis_hud_funder, funder: funder, project: project, data_source: project.data_source)
      end
    end
  end
end
