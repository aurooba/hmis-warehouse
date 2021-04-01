###
# Copyright 2016 - 2021 Green River Data Analysis, LLC
#
# License detail: https://github.com/greenriver/hmis-warehouse/blob/production/LICENSE.md
###

require 'sharepoint-ruby'
require 'sharepoint-http-auth'
require 'csv'
require 'charlock_holmes'

module Health::Tasks
  class ImportEpicSharePoint < ImportEpic
    def run!
      binding.pry
      @configs.each do |_, config|
        @config = config
        ds = Health::DataSource.find_by(name: config['data_source_name'])
        @data_source_id = ds.id
        fetch_files(@config) unless @load_locally
        # import_files
        # update_consent
        # sync_epic_pilot_patients
        # update_housing_statuses
        # return change_counts
      end
    end

    def fetch_files(config)
      site = Sharepoint::Site.new(config['url'], config['site-name'])
      site.session = Sharepoint::HttpAuth::Session.new(site)
      site.session.authenticate(config['user'], config['pass'])
    end
  end
end
