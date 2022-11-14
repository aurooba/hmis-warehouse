module Types
  class HmisSchema::EnrollmentHouseholdMemberInput < BaseInputObject
    description 'HMIS Enrollment household member input'

    argument :id, ID, required: true
    argument :relationship_to_ho_h, HmisSchema::Enums::Hud::RelationshipToHoh, required: true
  end
end
