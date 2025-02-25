###
# Copyright 2016 - 2023 Green River Data Analysis, LLC
#
# License detail: https://github.com/greenriver/hmis-warehouse/blob/production/LICENSE.md
###

class Hmis::BaseController < ApplicationController
  include Hmis::Concerns::JsonErrors
  respond_to :json
  before_action :set_csrf_cookie

  private def set_csrf_cookie
    cookies['CSRF-Token'] = form_authenticity_token
  end

  def authenticate_user!
    authenticate_hmis_user!
  end

  # Override the devise implementation to reset the session
  # and return 401, instead of raising InvalidAuthenticityToken
  def handle_unverified_request
    reset_session
    render_json_error(401, :unverified_request)
  end

  def current_hmis_host
    URI.parse(request.origin).host
  end

  def attach_data_source_id
    domain = current_hmis_host

    # In development: treat requests from GraphiQL as if they are coming from the local frontend
    domain = ENV['HMIS_HOSTNAME'] if Rails.env.development? && domain == ENV['HOSTNAME'] && ENV['HMIS_HOSTNAME'].present?

    data_source_id = GrdaWarehouse::DataSource.hmis.find_by(hmis: domain)&.id
    raise 'HMIS data source not configured' unless data_source_id.present?

    current_hmis_user.hmis_data_source_id = data_source_id
  end

  # PaperTrail whodunnit (set in ApplicationController) uses this method to determine the label to be stored
  def user_for_paper_trail
    current_hmis_user&.id
  end

  before_action :set_app_user_header
  def set_app_user_header
    response.headers['X-app-user-id'] = current_hmis_user&.id
  end
end
