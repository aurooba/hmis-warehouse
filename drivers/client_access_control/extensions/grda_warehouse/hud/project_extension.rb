###
# Copyright 2016 - 2023 Green River Data Analysis, LLC
#
# License detail: https://github.com/greenriver/hmis-warehouse/blob/production/LICENSE.md
###

module ClientAccessControl::GrdaWarehouse::Hud
  module ProjectExtension
    extend ActiveSupport::Concern

    included do
      scope :visible_to, ->(user, confidential_scope_limiter: :non_confidential) do
        viewable_by(user, confidential_scope_limiter: confidential_scope_limiter)
      end
    end
  end
end
