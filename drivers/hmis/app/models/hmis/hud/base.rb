###
# Copyright 2016 - 2023 Green River Data Analysis, LLC
#
# License detail: https://github.com/greenriver/hmis-warehouse/blob/production/LICENSE.md
###

class Hmis::Hud::Base < ::GrdaWarehouseBase
  self.abstract_class = true
  include ::Hmis::Concerns::HmisArelHelper

  acts_as_paranoid(column: :DateDeleted)
  has_paper_trail # Track changes made to HUD objects via PaperTrail

  attr_writer :skip_validations
  attr_writer :required_fields

  before_validation :ensure_id

  scope :viewable_by, ->(_) do
    none
  end

  def self.hmis_relation(col, model_name = nil)
    h = {
      primary_key: [
        :data_source_id,
        col,
      ],
      foreign_key: [
        :data_source_id,
        col,
      ],
      autosave: false,
    }
    h.merge! class_name: "Hmis::Hud::#{model_name}" if model_name
    h
  end

  def self.alias_to_underscore(cols)
    Array.wrap(cols).each do |col|
      alias_attribute col.to_s.underscore.to_sym, col
    end
  end

  # Create aliases for common HUD fields
  alias_to_underscore [:UserID, :DateCreated, :DateUpdated, :DateDeleted]

  def self.generate_uuid
    SecureRandom.uuid.gsub(/-/, '')
  end

  # Fields that should be skipped during validation.
  def skip_validations
    @skip_validations ||= []
  end

  # Fields that should be validated as required during validation.
  # NOTE: No need to add fields here if they are not already required by the warehouse validator.
  def required_fields
    @required_fields ||= []
  end

  private def ensure_id
    return unless self.class.respond_to?(:hud_key)
    return if send(self.class.hud_key).present? # Don't overwrite the ID if we already have one

    assign_attributes(self.class.hud_key => self.class.generate_uuid)
  end

  # Let Rails update the HUD timestamps
  def self.timestamp_attributes_for_create
    super << 'DateCreated'
  end

  def self.timestamp_attributes_for_update
    super << 'DateUpdated'
  end
end
