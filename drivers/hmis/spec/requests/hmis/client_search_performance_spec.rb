###
# Copyright 2016 - 2023 Green River Data Analysis, LLC
#
# License detail: https://github.com/greenriver/hmis-warehouse/blob/production/LICENSE.md
###

require 'rails_helper'
require_relative 'login_and_permissions'
require_relative '../../support/hmis_base_setup'

RSpec.describe Hmis::GraphqlController, type: :request do
  include_context 'hmis base setup'

  before(:all) do
    cleanup_test_environment
  end

  let(:search_term) { 'ross' }
  let!(:enrollments) do
    10.times.map do
      client = create :hmis_hud_client_complete, data_source: ds1, user: u1, LastName: search_term
      create :hmis_hud_enrollment, data_source: ds1, project: p1, client: client, user: u1
    end
  end

  let!(:ds_access_control) do
    create_access_control(hmis_user, ds1, with_permission: [:can_view_clients, :can_view_dob, :can_view_enrollment_details])
  end

  before(:each) do
    hmis_login(user)
  end

  describe 'client search' do
    let(:query) do
      <<~GRAPHQL
        query SearchClients($input: ClientSearchInput!, $limit: Int, $offset: Int, $sortOrder: ClientSortOption = LAST_NAME_A_TO_Z) {
          clientSearch(
            input: $input
            limit: $limit
            offset: $offset
            sortOrder: $sortOrder
          ) {
            offset
            limit
            nodesCount
            nodes {
              ...ClientFields
              __typename
            }
            __typename
          }
        }

        fragment ClientFields on Client {
          ...ClientIdentificationFields
          dobDataQuality
          ethnicity
          gender
          pronouns
          nameDataQuality
          personalId
          race
          ssnDataQuality
          veteranStatus
          dateCreated
          dateDeleted
          dateUpdated
          ...ClientName
          ...ClientImage
          externalIds {
            ...ClientIdentifierFields
            __typename
          }
          user {
            ...UserFields
            __typename
          }
          access {
            ...ClientAccessFields
            __typename
          }
          customDataElements {
            ...CustomDataElementFields
            __typename
          }
          names {
            ...ClientNameObjectFields
            __typename
          }
          addresses {
            ...ClientAddressFields
            __typename
          }
          phoneNumbers {
            ...ClientContactPointFields
            __typename
          }
          emailAddresses {
            ...ClientContactPointFields
            __typename
          }
          __typename
        }

        fragment ClientIdentificationFields on Client {
          id
          dob
          age
          ssn
          access {
            id
            canViewFullSsn
            canViewPartialSsn
            __typename
          }
          __typename
        }

        fragment ClientName on Client {
          firstName
          middleName
          lastName
          nameSuffix
          __typename
        }

        fragment ClientImage on Client {
          id
          image {
            ...ClientImageFields
            __typename
          }
          __typename
        }

        fragment ClientImageFields on ClientImage {
          id
          contentType
          base64
          __typename
        }

        fragment ClientIdentifierFields on ExternalIdentifier {
          id
          identifier
          url
          label
          __typename
        }

        fragment UserFields on User {
          __typename
          id
          name
        }

        fragment ClientAccessFields on ClientAccess {
          id
          canEditClient
          canDeleteClient
          canViewDob
          canViewFullSsn
          canViewPartialSsn
          canEditEnrollments
          canDeleteEnrollments
          canViewEnrollmentDetails
          canDeleteAssessments
          canManageAnyClientFiles
          canManageOwnClientFiles
          canViewAnyConfidentialClientFiles
          canViewAnyNonconfidentialClientFiles
          __typename
        }

        fragment CustomDataElementFields on CustomDataElement {
          id
          key
          label
          repeats
          value {
            ...CustomDataElementValueFields
            __typename
          }
          values {
            ...CustomDataElementValueFields
            __typename
          }
          __typename
        }

        fragment CustomDataElementValueFields on CustomDataElementValue {
          id
          valueBoolean
          valueDate
          valueFloat
          valueInteger
          valueJson
          valueString
          valueText
          user {
            ...UserFields
            __typename
          }
          dateCreated
          dateUpdated
          __typename
        }

        fragment ClientNameObjectFields on ClientName {
          id
          first
          middle
          last
          suffix
          nameDataQuality
          use
          notes
          primary
          dateCreated
          dateUpdated
          __typename
        }

        fragment ClientAddressFields on ClientAddress {
          id
          line1
          line2
          city
          state
          district
          country
          postalCode
          notes
          use
          addressType
          dateCreated
          dateUpdated
          __typename
        }

        fragment ClientContactPointFields on ClientContactPoint {
          id
          value
          notes
          use
          system
          dateCreated
          dateUpdated
          __typename
        }
      GRAPHQL
    end

    let(:variables) do
      {
        "sortOrder": 'LAST_NAME_A_TO_Z',
        "input": {
          "textSearch": search_term,
        },
        "limit": 20,
        "offset": 0,
      }
    end

    it 'minimizes n+1 queries' do
      # TODO(#185555687): improve performance of client search, decrease the upper bound here
      expect do
        _, result = post_graphql(**variables) { query }
        expect(result.dig('data', 'clientSearch', 'nodes').size).to eq(enrollments.size)
      end.to make_database_queries(count: 10..50)
    end

    it 'is responsive' do
      expect do
        _, result = post_graphql(**variables) { query }
        expect(result.dig('data', 'clientSearch', 'nodes').size).to eq(enrollments.size)
      end.to perform_under(400).ms
    end
  end
end

RSpec.configure do |c|
  c.include GraphqlHelpers
end
