###
# Copyright 2016 - 2023 Green River Data Analysis, LLC
#
# License detail: https://github.com/greenriver/hmis-warehouse/blob/production/LICENSE.md
###

module HmisExternalApis
  class InboundApiConfiguration < GrdaWarehouseBase
    KEY_LENGTH = 64
    MAX_KEYS_PER_COMBO = 2

    attr_accessor :plain_text_api_key

    belongs_to :internal_system

    scope :well_ordered, -> { joins(:internal_system).order('internal_systems.name, version') }
    scope :versions, ->(e, i) { where(external_system_name: e, internal_system_id: i).order('version desc') }

    before_validation :set_version, if: :new_record?
    before_create :generate_key
    after_save :keep_two_versions

    validates :external_system_name, length: { minimum: 2 }
    validates :hashed_api_key, uniqueness: true
    validates :external_system_name, uniqueness: { scope: [:internal_system_id, :version], case_sensitive: false }

    def generate_key
      return if hashed_api_key.present?

      self.plain_text_api_key = SecureRandom.hex(KEY_LENGTH / 2)

      expires_in = Rails.env.development? ? 30.seconds : 30.minutes

      Rails.cache.write(cache_key, plain_text_api_key, expires_in: expires_in)

      self.hashed_api_key = Digest::SHA512.hexdigest(plain_text_api_key)
      self.plain_text_reminder = plain_text_api_key[0, 10] + '*' * (KEY_LENGTH - 10)
    end

    def self.validate(api_key:, internal_system:)
      !!find_by(hashed_api_key: Digest::SHA512.hexdigest(api_key.downcase.strip), internal_system: internal_system)
    end

    def plain_text_api_key_with_fallback
      Rails.cache.read(cache_key) || plain_text_reminder
    end

    private

    def cache_key
      "inbound-api-configuration--internal-id-#{internal_system_id}--#{external_system_name}--#{version}"
    end

    def set_version
      self.version = next_version
    end

    def next_version
      v = InboundApiConfiguration.versions(external_system_name, internal_system_id).first

      v.nil? ? 0 : v.version.to_i + 1
    end

    def keep_two_versions
      InboundApiConfiguration.versions(external_system_name, internal_system_id).offset(MAX_KEYS_PER_COMBO).delete_all
    end
  end
end
