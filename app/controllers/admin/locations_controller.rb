###
# Copyright 2016 - 2023 Green River Data Analysis, LLC
#
# License detail: https://github.com/greenriver/hmis-warehouse/blob/production/LICENSE.md
###

module Admin
  class LocationsController < ::ApplicationController
    before_action :require_can_audit_users!

    def show
      @user = User.find params[:user_id]
      @locations = @user.login_activities.order(created_at: :desc)
      @pagy, @locations = pagy(@locations, items: 50)
    end
  end
end
