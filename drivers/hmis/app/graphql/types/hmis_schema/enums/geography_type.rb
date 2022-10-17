###
# Copyright 2016 - 2022 Green River Data Analysis, LLC
#
# License detail: https://github.com/greenriver/hmis-warehouse/blob/production/LICENSE.md
###

# frozen_string_literal: true

module Types
  class HmisSchema::Enums::GeographyType < Types::BaseEnum
    description 'HUD Geography Type (2.8.7)'
    graphql_name 'GeographyType'

    with_enum_map Hmis::Hud::ProjectCoc.geography_type_enum_map
  end
end
