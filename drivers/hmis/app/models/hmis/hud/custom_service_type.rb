###
# Copyright 2016 - 2023 Green River Data Analysis, LLC
#
# License detail: https://github.com/greenriver/hmis-warehouse/blob/production/LICENSE.md
###

class Hmis::Hud::CustomServiceType < Hmis::Hud::Base
  self.table_name = :CustomServiceTypes

  belongs_to :data_source, class_name: 'GrdaWarehouse::DataSource'
  belongs_to :user, **hmis_relation(:UserID, 'User')
  belongs_to :custom_service_category
  has_many :custom_services

  alias_attribute :category, :custom_service_category

  validates :hud_record_type, uniqueness: { scope: [:hud_type_provided] }, allow_nil: true
  validates :name, uniqueness: { scope: [:custom_service_category] }
  validates_with Hmis::Hud::Validators::CustomServiceTypeValidator

  def hud_service?
    hud_record_type.present?
  end

  def to_pick_list_option
    {
      code: id.to_s,
      label: name,
      group_label: custom_service_category.name,
    }
  end
end
