###
# Copyright 2016 - 2023 Green River Data Analysis, LLC
#
# License detail: https://github.com/greenriver/hmis-warehouse/blob/production/LICENSE.md
###

require 'rails_helper'
require_relative 'login_and_permissions'
require_relative '../../support/hmis_base_setup'

RSpec.describe Hmis::GraphqlController, type: :request do
  before(:all) do
    cleanup_test_environment
  end
  after(:all) do
    cleanup_test_environment
  end

  include_context 'hmis base setup'
  include_context 'hmis service setup'
  let!(:access_control) { create_access_control(hmis_user, p1) }
  let!(:c1) { create :hmis_hud_client, data_source: ds1, user: u1 }
  let!(:e1) { create :hmis_hud_enrollment, data_source: ds1, client: c1, project: p1, user: u1 }
  let!(:hud_s1) { create :hmis_hud_service, data_source: ds1, client: c1, enrollment: e1, user: u1 }
  let(:s1) { Hmis::Hud::HmisService.find_by(owner: hud_s1) }

  before(:each) do
    hmis_login(user)
  end

  let(:mutation) do
    <<~GRAPHQL
      mutation DeleteService($id: ID!) {
        deleteService(input: { id: $id }) {
          service {
            id
            enrollment {
              id
            }
            client {
              id
            }
            user{
              id
            }
            dateProvided
            subTypeProvided
            otherTypeProvided
            movingOnOtherType
            faAmount
            referralOutcome
          }
          #{error_fields}
        }
      }
    GRAPHQL
  end

  it 'should delete a service successfully' do
    response, result = post_graphql(id: s1.id) { mutation }

    aggregate_failures 'checking response' do
      expect(response.status).to eq 200
      errors = result.dig('data', 'deleteService', 'errors')
      expect(errors).to be_empty
      expect(Hmis::Hud::Service.count).to eq(0)
    end
  end

  it 'should error if a service does not exist' do
    expect_gql_error post_graphql(id: '123') { mutation }
  end

  it 'should error if not allowed to delete a service' do
    remove_permissions(access_control, :can_edit_enrollments)
    expect_gql_error post_graphql(id: s1.id) { mutation }
  end
end

RSpec.configure do |c|
  c.include GraphqlHelpers
end
