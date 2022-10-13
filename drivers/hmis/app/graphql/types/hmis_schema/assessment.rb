###
# Copyright 2016 - 2022 Green River Data Analysis, LLC
#
# License detail: https://github.com/greenriver/hmis-warehouse/blob/production/LICENSE.md
###

# frozen_string_literal: true

module Types
  class HmisSchema::Assessment < Types::BaseObject
    description 'HUD Assessment'
    field :id, ID, null: false
    field :enrollment, HmisSchema::Enrollment, null: false
    field :assessment_date, GraphQL::Types::ISO8601DateTime, null: false
    field :assessment_location, String, null: false
    field :assessment_type, HmisSchema::Enums::AssessmentType, null: false
    field :assessment_level, HmisSchema::Enums::AssessmentLevel, null: false
    field :prioritization_status, HmisSchema::Enums::PrioritizationStatus, null: false
    field :date_created, GraphQL::Types::ISO8601DateTime, null: false
    field :date_updated, GraphQL::Types::ISO8601DateTime, null: false
    field :date_deleted, GraphQL::Types::ISO8601DateTime, null: true
    field :assessment_detail, HmisSchema::AssessmentDetail, null: true
    # field :user, HmisSchema::User, null: false

    def enrollment
      load_ar_association(object, :enrollment)
    end

    def assessment_detail
      load_ar_association(object, :assessment_detail)
    end

    # TODO: Add user type?
    # def user
    #   load_ar_association(object, :user)
    # end
  end
end
