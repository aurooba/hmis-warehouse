###
# Copyright 2016 - 2023 Green River Data Analysis, LLC
#
# License detail: https://github.com/greenriver/hmis-warehouse/blob/production/LICENSE.md
###

class Hmis::UsersController < Hmis::BaseController
  skip_before_action :authenticate_user!, only: [:show]
  prepend_before_action :skip_timeout, only: [:show]
  before_action :clear_etag, only: [:index]

  # Endpoint to retrieve the currently logged-in user.
  #
  # This is called by the frontend on initial page load, to determine whether
  # there is a currently active session.
  def show
    render json: (current_hmis_user&.current_user_api_values || {})
  end

  # clear etag to prevent caching
  def clear_etag
    response.headers['Etag'] = nil
  end
end
