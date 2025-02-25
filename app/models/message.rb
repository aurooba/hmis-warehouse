###
# Copyright 2016 - 2023 Green River Data Analysis, LLC
#
# License detail: https://github.com/greenriver/hmis-warehouse/blob/production/LICENSE.md
###

# email message stowed in database
class Message < ApplicationRecord
  SCHEDULES = ['immediate', 'daily'].freeze

  belongs_to :user
  scope :sent, ->(time = DateTime.current) { where arel_table[:sent_at].lteq time }
  scope :unsent, -> { where sent_at: nil }
  scope :seen, ->(time = DateTime.current) { where arel_table[:seen_at].lteq time }
  scope :unseen, -> { where seen_at: nil }
  scope :before, ->(time) { where arel_table[:created_at].lt time }

  # extract the body out of an html message
  def body_html
    return body unless html?

    Nokogiri(body).at('body').children.map(&:to_s).join.html_safe
  end

  def body_text
    return body unless html?

    Nokogiri(body).text
  end

  def opened?
    seen_at.present?
  end
end
