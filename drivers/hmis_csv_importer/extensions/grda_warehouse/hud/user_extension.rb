###
# Copyright 2016 - 2023 Green River Data Analysis, LLC
#
# License detail: https://github.com/greenriver/hmis-warehouse/blob/production/LICENSE.md
###

module HmisCsvImporter::GrdaWarehouse::Hud
  module UserExtension
    extend ActiveSupport::Concern

    included do
      has_many :imported_items_2022, class_name: '::HmisCsvTwentyTwentyTwo::Importer::User', primary_key: [:UserID, :data_source_id], foreign_key: [:UserID, :data_source_id]
      has_many :loaded_items_2022, class_name: '::HmisCsvTwentyTwentyTwo::Loader::User', primary_key: [:UserID, :data_source_id], foreign_key: [:UserID, :data_source_id]
    end
  end
end
