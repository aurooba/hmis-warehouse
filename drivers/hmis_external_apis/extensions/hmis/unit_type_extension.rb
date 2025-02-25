###
# Copyright 2016 - 2023 Green River Data Analysis, LLC
#
# License detail: https://github.com/greenriver/hmis-warehouse/blob/production/LICENSE.md
###

module HmisExternalApis
  module Hmis
    module UnitTypeExtension
      extend ActiveSupport::Concern
      include ExternallyIdentifiedMixin

      included do
        has_many :external_referral_requests, class_name: 'HmisExternalApis::AcHmis::ReferralRequest', dependent: :restrict_with_exception
        has_one :mper_id,
                -> { where(namespace: HmisExternalApis::AcHmis::Mper::SYSTEM_ID) },
                class_name: 'HmisExternalApis::ExternalId',
                as: :source
      end
    end
  end
end
