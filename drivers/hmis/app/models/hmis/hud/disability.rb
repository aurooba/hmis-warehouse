###
# Copyright 2016 - 2022 Green River Data Analysis, LLC
#
# License detail: https://github.com/greenriver/hmis-warehouse/blob/production/LICENSE.md
###

class Hmis::Hud::Disability < Hmis::Hud::Base
  include ::HmisStructure::Disability
  include ::Hmis::Hud::Shared
  self.table_name = :Disabilities
  self.sequence_name = "public.\"#{table_name}_id_seq\""

  belongs_to :enrollment, **hmis_relation(:EnrollmentID, 'Enrollment')

  use_enum :disability_type_enum_map, ::HUD.disability_types
  use_enum :disability_responses_enum_map, ::HUD.disability_responses
end
