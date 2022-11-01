###
# Copyright 2016 - 2022 Green River Data Analysis, LLC
#
# License detail: https://github.com/greenriver/hmis-warehouse/blob/production/LICENSE.md
###

class Hmis::AccessGroupMember < ApplicationRecord
  acts_as_paranoid
  has_paper_trail(
    meta: {
      referenced_user_id: :referenced_user_id,
      referenced_entity_name: :referenced_entity_name,
    },
  )

  belongs_to :access_group, class_name: '::Hmis::AccessGroup', optional: true
  belongs_to :user, class_name: 'Hmis::User', optional: true

  def referenced_user_id
    user.id
  end

  def referenced_entity_name
    access_group.name
  end

  def self.describe_changes(version, _changes)
    if version.event == 'create'
      ["Added group #{version.referenced_entity_name}"]
    else
      ["Removed group #{version.referenced_entity_name}"]
    end
  end
end
