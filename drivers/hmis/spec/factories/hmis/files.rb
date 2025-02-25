###
# Copyright 2016 - 2023 Green River Data Analysis, LLC
#
# License detail: https://github.com/greenriver/hmis-warehouse/blob/production/LICENSE.md
###

FactoryBot.define do
  factory :file, class: 'Hmis::File' do
    transient do
      blob { nil }
      tags { [] }
    end

    name { blob&.filename || 'File' }
    effective_date { Date.today }
    expiration_date { Date.tomorrow }
    confidential { false }
    visible_in_window { false }
    user { association :hmis_user }

    before(:create) do |file, evaluator|
      file.client_file.attach(evaluator.blob) if evaluator.blob
      file.tag_list = evaluator.tags.map(&:id)
    end
  end
end
