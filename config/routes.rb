Rails.application.routes.draw do
  # For details on the DSL available within this file, see http://guides.rubyonrails.org/routing.html
  match "/404", to: "errors#not_found", via: :all
  match "/422", to: "errors#unacceptable", via: :all
  match "/500", to: "errors#internal_server_error", via: :all

  require 'rails_drivers/routes'
  RailsDrivers::Routes.load_driver_routes

  class OnlyXhrRequest
    def matches?(request)
      request.xhr?
    end
  end
  devise_for :users, controllers: {
    invitations: 'users/invitations',
    sessions: 'users/sessions',
  }

  devise_scope :user do
    match 'active' => 'users/sessions#active', via: :get
    match 'timeout' => 'users/sessions#timeout', via: :get
    match 'users/invitations/confirm', via: :post
    match 'logout_talentlms' => 'users/sessions#destroy', via: :get
    if ENV['OKTA_DOMAIN'].present?
      get "/users/auth/okta/callback" => "users/omniauth_callbacks#okta" if ENV['OKTA_CLIENT_ID']
    end
  end

  namespace :users do
    resources :invitations do
      collection do
        post :confirm
      end
    end
    resources :account_requests, only: [:new, :create]
  end

  get '/user_training', to: 'user_training#index'

  def healthcare_routes(window:)
    namespace :health do
      resources :patient, only: [:index, :update], controller: '/health/patient'
      resources :utilization, only: [:index], controller: '/health/utilization'
      resources :appointments, only: [:index], controller: '/health/appointments' do
        collection do
          get :upcoming
          get :calendar
        end
      end
      resources :ed_ip_visits, only: [:index], controller: '/health/ed_ip_visits'
      resources :medications, only: [:index], controller: '/health/medications'
      resources :problems, only: [:index], controller: '/health/problems'
      resources :self_sufficiency_matrix_forms, controller: '/health/self_sufficiency_matrix_forms' do
        member do
          delete :remove_file
          get :download
          patch :upload
        end
      end
      resources :sdh_case_management_notes, only: [:show, :new, :create, :edit, :update, :destroy], controller: '/health/sdh_case_management_notes' do
        member do
          delete :remove_file
          get :download
        end
      end
      resources :services, controller: '/health/services'
      resources :backup_plans, controller: '/health/backup_plans'
      resources :qualifying_activities, controller: '/health/qualifying_activities'
      resources :patient_referrals, only: [:index], controller: '/health/patient_referrals'
      resources :durable_equipments, except: [:index], controller: '/health/durable_equipments'
      resources :files, only: [:index, :show], controller: '/health/files'
      resources :team_members, controller: '/health/patient_team_members'
      resources :goals, controller: '/health/patient_goals'
      resources :epic_case_notes, only: [:show], controller: '/health/epic_case_notes'
      resources :epic_ssms, only: [:show], controller: '/health/epic_ssms'
      resources :epic_chas, only: [:show], controller: '/health/epic_chas'
      resources :epic_careplans, only: [:show], controller: '/health/epic_careplans'
      resources :careplans, except: [:create], controller: '/health/careplans' do
        resources :team_members, except: [:index, :show], controller: '/health/team_members'
        resources :goals, except: [:index, :show], controller: '/health/goals'
        resources :signable_documents, only: [:show, :create], controller: '/health/signable_documents' do
          member do
            # post :remind
            get :signature
            get :signed
          end
        end
        resources :pcp_signature_requests, except: [:index], controller: '/health/pcp_signature_requests'
        resources :aco_signature_requests, except: [:index], controller: '/health/aco_signature_requests' do
          member do
            get :download_careplan
          end
        end

        get :self_sufficiency_assessment
        get :print
        get :revise, on: :member
        get :coversheet, on: :member
        get :pctp, on: :member
        member do
          delete :remove_file
          get :download
          patch :upload
        end
      end
      resources :participation_forms, controller: '/health/participation_forms' do
        member do
          delete :remove_file
          get :download
        end
      end
      resources :release_forms, controller: '/health/release_forms' do
        member do
          delete :remove_file
          get :download
        end
      end
      resources :comprehensive_health_assessments, path: :chas, as: :chas, controller: '/health/comprehensive_health_assessments' do
        member do
          delete :remove_file
          get :download
          patch :upload
        end
      end
      resources :metrics, only: [:index], controller: '/health/metrics'
      namespace :pilot do
        resources :patient, only: [:index], controller: '/health/pilot/patient'
        resources :metrics, only: [:index], controller: '/health/pilot/metrics'
        resource :careplan, except: [:destroy], controller: '/health/pilot/careplans' do
          get :self_sufficiency_assessment
          get :print
        end
      end
      resources :contacts, only: [:index], controller: '/health/contacts'
    end
  end

  # obfuscation of links sent out via email
  resources :tokens, only: [:show]

  match 'filter', to: 'filters#show', via: [:post]


  resources :reports do
    resources :report_results, path: 'results', only: [:index, :show, :create, :update, :destroy] do
      get :download_support, on: :member
      resources :support, only: [:index], controller: 'report_results/support'
    end
  end

  resources :secure_files, only: [:show, :create, :index, :destroy]
  resources :help
  resources :maintenance, only: [:index]
  resources :maintenance_saver, only: [:index], controller: 'maintenance'

  namespace :reports do
    namespace :hic do
      resource :export, only: [:show, :create]
      resource :organization, only: [:show]
      resource :project, only: [:show]
      resource :inventory, only: [:show]
      resource :site, only: [:show]
      resource :geography, only: [:show]
      resource :funder, only: [:show]
      resource :project_coc, only: [:show]
    end
  end
  namespace :hud_reports do
    resources :historic_pits, only: [:index]
    resources :historic_lsas, only: [:index], controller: 'lsas'
  end
  resources :report_results_summary, only: [:show]
  resources :warehouse_reports, only: [:index] do
    resources :support, only: [:index], controller: 'warehouse_reports/support'
  end
  namespace :audit_reports do
    resources :agency_user, only: [:index]
    resources :user_login, only: [:index]
  end
  namespace :warehouse_reports do
    resources :client_lookups, only: [:index]
    resources :overlapping_coc_utilization, only: [:index] do
      collection do
        get :overlap
        get :details
        get :clients
      end
    end
    resources :ce_assessments, only: [:index]
    resources :dv_victim_service, only: [:index]
    resources :conflicting_client_attributes, only: [:index]
    resources :inactive_youth_intakes, only: [:index]
    resources :youth_intakes, only: [:index] do
      collection do
        get :details
      end
    end
    resources :youth_follow_ups, only: [:index]
    resources :youth_export, only: [:index, :show, :create, :destroy]
    resources :youth_intake_export, only: [:index, :create]
    resources :youth_activity, only: [:index]
    resources :incomes, only: [:index]
    resources :project_type_reconciliation, only: [:index]
    resources :missing_projects, only: [:index]
    resources :dob_entry_same, only: [:index]
    resources :non_alpha_names, only: [:index]
    resources :future_enrollments, only: [:index]
    resources :long_standing_clients, only: [:index]
    resources :really_old_enrollments, only: [:index]
    resources :entry_exit_service, only: [:index]
    resources :recidivism, only: [:index]
    resources :expiring_consent, only: [:index]
    resources :export_covid_impact_assessments, only: [:index]
    resources :rrh, only: [:index], defaults: {scope: :rrh}, controller: :outcomes do
      collection do
        get :clients
      end
    end
    resources :psh, only: [:index], defaults: {scope: :psh}, controller: :outcomes do
      collection do
        get :clients
      end
    end
    resources :shelter, only: [:index], defaults: {scope: :es}, controller: :outcomes do
      collection do
        get :clients
      end
    end
    resources :th, only: [:index], defaults: {scope: :th}, controller: :outcomes do
      collection do
        get :clients
      end
    end
    resources :consent, only: [:index] do
      post :update_clients, on: :collection
    end
    resources :anomalies, only: [:index]
    resources :touch_point_exports, only: [:index, :create, :show, :destroy]
    resources :confidential_touch_point_exports, only: [:index, :create, :show, :destroy]
    resources :hmis_exports, except: [:new] do
      collection do
        get :running
      end
      member do
        delete :cancel
      end
    end
    resources :hashed_only_hmis_exports, except: [:edit, :update, :new] do
      collection do
        get :running
      end
    end
    resources :initiatives, except: [:edit, :update, :new] do
      get '(/:token)', controller: 'initiatives', action: :show, on: :member
      collection do
        get :running
      end
    end
    resources :disabilities, only: [:index, :create, :show, :destroy] do
      collection do
        get :summary
        get :running
      end
    end
    resources :chronic, only: [:index, :show, :destroy] do
      get :summary, on: :collection
      get :running, on: :collection
    end
    resources :hud_chronics, only: [:index, :show, :destroy] do
      collection do
        get :summary
        get :running
      end
    end
    resources :active_veterans, only: [:index, :show, :destroy] do
      collection do
        get :summary
        get :running
      end
    end
    resources :chronic_housed, only: [:index]
    resources :first_time_homeless, only: [:index] do
      get :summary, on: :collection
    end
    resources :client_in_project_during_date_range, only: [:index]
    resources :enrolled_project_type, only: [:index]
    resources :bed_utilization, only: [:index]
    resources :length_of_stay, only: [:index] do
      collection do
        get :fetch_length
      end
    end
    resources :missing_values, only: [:index]
    resources :active_veterans, only: [:index]
    resources :tableau_dashboard_export, only: [:index, :create, :show, :destroy] do
      collection do
        get :running
      end
    end
    namespace :client_details do
      resources :exits, only: [:index] do
        post :render_section, on: :collection
        get :section, on: :collection
      end
      resources :entries, only: [:index] do
        post :render_section, on: :collection
        get :section, on: :collection
      end
      resources :actives, only: [:index] do
        post :render_section, on: :collection
        get :section, on: :collection
      end
    end
    resources :re_entry, only: [:index]
    resources :open_enrollments_no_service, only: [:index]
    resources :manage_cas_flags, only: [:index] do
      post :bulk_update, on: :collection
    end
    resources :find_by_id, only: [:index] do
      post :search, on: :collection
    end
    resources :cohort_changes, only: [:index]
    resources :outflow, only: [:index] do
      collection do
        get :details
      end
    end
    resources :ad_hoc_analysis, only: [:index, :create, :destroy, :show]
    resources :ad_hoc_anon_analysis, only: [:index, :create, :destroy, :show]
    resources :hmis_cross_walks, only: [:index]
    resources :time_homeless_for_exits, only: [:index]
    namespace :project do
      resource :data_quality do
        get :download, on: :member
        get :history, on: :member
      end
    end
    namespace :health_emergency do
      resources :testing_results, only: [:index]
      resources :vaccinations, only: [:index]
      resources :uploaded_results, only: [:index, :create, :new, :show]
      resources :medical_restrictions, only: [:index]
    end
    namespace :cas do
      resources :decision_efficiency, only: [:index] do
        collection do
          get :chart
        end
      end
      resources :decline_reason, only: [:index]
      resources :rrh_desired, only: [:index]
      resources :canceled_matches, only: [:index]
      resources :process, only: [:index]
      resources :apr, only: [:index]
      resources :vacancies, only: [:index]
      resources :ce_assessments, only: [:index]
      resources :chronic_reconciliation, only: [:index] do
        collection do
          patch :update
        end
      end
      resources :health_prioritization, only: [:index] do
        member do
          patch :client
        end
      end
      resources :non_hmis_clients, only: [:index] do
        patch :match, on: :collection
      end
    end
    namespace :health do
      resources :overview, only: [:index]
      resources :aco_performance, only: [:index]
      resources :agency_performance, only: [:index] do
        collection do
          post :detail
        end
      end
      resources :member_status_reports, only: [:index, :show, :create, :destroy] do
        collection do
          get :running
        end
      end
      resources :claims, only: [:index, :show, :destroy] do
        collection do
          get :running
          post :precalculate
          post :qualifying_activities
          get :precalculated
          get :patients
        end
        member do
          post :generate_claims_file
          post :revise
          post :submit
          post :acknowledge
          get :details
          get :accept
        end
      end
      resources :patient_referrals, only: [:index] do
        collection do
          patch :update
        end
      end
      resources :premium_payments, only: [:index, :show, :create, :destroy]
      resources :eligibility
      resources :eligibility_results, only: [:show]
      resources :enrollments do
        get :download, on: :member
        post :override, on: :member
      end
      resources :expiring_items, only: [:index]
      resources :ssm_exports, only: [:index, :show, :create, :destroy]
      resources :encounters, only: [:index, :show, :create, :destroy]
      resources :housing_status, only: [:index] do
        get :details, on: :collection
      end
      resources :housing_status_changes, only: [:index] do
        collection do
          get :detail
        end
      end
      resources :cp_roster, only: [:index, :show, :destroy] do
        collection do
          post :roster
          post :enrollment
        end
      end
      resources :ed_ip_visits, only: [:index, :show, :create, :destroy]
      resources :contact_tracing, only: [:index] do
        get :download, on: :collection
        get :single_case, on: :member
      end
      resources :completed_contact_tracing, only: [:index] do
        get :download, on: :collection
      end
      resources :enrollments_disenrollments, only: [:index, :create] do
        get :download, on: :member
      end
    end
  end

  resources :client_matches, only: [:index, :update] do
    post :defer, on: :collection
    post :defer, on: :member
  end
  resources :source_clients, only: [:edit, :update] do
    member do
      get :image
      get :destination
    end
  end

  resources :clients, only: [:create, :update, :edit] do
    member do
      # get :appropriate
      # get :simple
      get :service_range
      get 'rollup/:partial', to: 'clients#rollup', as: :rollup
      get :assessment
      get :health_assessment
      # get :image
      get :chronic_days
      patch :merge
      patch :unmerge
      resource :cas_active, only: :update
      resources :enrollment_history, only: :index, controller: 'clients/enrollment_history'
      # get :enrollment_details
    end
    resources :hud_assessments, only: [:show], controller: 'clients/hud_assessments'
    # resource :history, only: [:show], controller: 'clients/history' do
    #   get :pdf, on: :collection
    #   post :queue, on: :collection
    # end
    resource :cas_readiness, only: [:edit, :update], controller: 'clients/cas_readiness'
    resource :chronic, only: [:edit, :update], controller: 'clients/chronic'
    resources :vispdats, controller: 'clients/vispdats' do
      member do
        put :add_child
          delete :remove_child
          put :upload_file
          delete :destroy_file
      end
    end
    resources :coordinated_entry_assessments, controller: 'clients/coordinated_entry_assessments'
    resources :youth_intakes, controller: 'clients/youth/intakes' do
      delete :remove_all_youth_data, on: :collection
    end
    resources :youth_case_managements, except: [:index], controller: 'clients/youth/case_managements'
    resources :direct_financial_assistances, only: [:create, :destroy], controller: 'clients/youth/direct_financial_assistances'
    resources :youth_referrals, only: [:create, :destroy], controller: 'clients/youth/referrals'
    resources :youth_follow_ups, except: [:index], controller: 'clients/youth/follow_ups'
    resources :housing_resolution_plans, except: [:index], controller: 'clients/youth/housing_resolution_plans'
    resources :psc_feedback_surveys, except: [:index], controller: 'clients/youth/psc_feedback_surveys'

    resources :files, controller: 'clients/files', except: [:edit] do
      get :preview, on: :member
      get :thumb, on: :member
      get :show_delete_modal, on: :member
      post :batch_download, on: :collection
    end
    resources :releases, controller: 'clients/releases', except: [:edit] do
      get :preview, on: :member
      get :thumb, on: :member
      get :show_delete_modal, on: :member
      post :batch_download, on: :collection
      get :pre_populated, on: :collection
    end
    resources :notes, only: [:index, :destroy, :create], controller: 'clients/notes' do
      get :alerts, on: :collection
    end
    resources :enrollments, only: [:show], controller: 'clients/enrollments'
    resource :eto_api, only: [:show, :update], controller: 'clients/eto_api'
    resources :users, only: [:index, :create, :update, :destroy], controller: 'clients/users'
    resources :anomalies, except: [:show], controller: 'clients/anomalies'
    resources :audits, only: [:index], controller: 'clients/audits'
    resources :hud_lots, only: [:index], controller: 'clients/hud_lots'
    healthcare_routes(window: false)
    namespace :he do
      get :boston_covid_19
      get :covid_19_vaccinations_only
      resources :triages, only: [:create, :destroy]
      resources :clinicals, only: [:destroy] do
        collection do
          post :triage
          post :test
          post :isolation
          post :quarantine
          post :vaccination
        end
        member do
          delete :destroy_triage
          delete :destroy_test
          delete :destroy_isolation
          delete :destroy_vaccination
        end
      end
      resources :ama_restrictions, only: [:create, :destroy]
    end
  end
  # END clients

  namespace :assigned do
    resources :clients, only: [:index]
    resources :agencies, only: [:index]
    resources :all_agencies, only: [:index]
  end
  namespace :expired do
    resources :clients, only: :index
  end

  resources :censuses, only: [:index] do
    get :date_range, on: :collection
    get :details, on: :collection
  end

  resources :dashboards, only: [:index]

  namespace :performance_dashboards do
    resources :overview, only: [:index] do
      get :details, on: :collection
      get 'section/:partial', on: :collection, to: "overview#section", as: :section
      get :filters, on: :collection
      get :download, on: :collection
    end
    resources :household, only: [:index] do
      get :details, on: :collection
      get 'section/:partial', on: :collection, to: "household#section", as: :section
      get :filters, on: :collection
      get :download, on: :collection
    end
    resources :project_type, only: [:index] do
      get :details, on: :collection
      get 'section/:partial', on: :collection, to: "project_type#section", as: :section
      get :filters, on: :collection
      get :download, on: :collection
    end
  end

  resources :cohort_column_options, except: [:destroy]

  resources :cohort_column_names, only: [:new, :create]

  resources :cohorts do
    resource :columns, only: [:edit, :update], controller: 'cohorts/columns'
    resources :cohort_clients, controller: 'cohorts/clients' do
      get :pre_destroy, on: :member
      post :pre_bulk_destroy, on: :collection
      delete :bulk_destroy, on: :collection
      post :bulk_restore, on: :collection
      get :field, on: :member
      patch :re_rank, on: :collection
      resources :cohort_client_notes, controller: 'cohorts/notes'
      resources :client_notes, controller: 'cohorts/client_notes'
    end
    resource :report, on: :member, only: [:show], controller: 'cohorts/reports'
    resource :copy, only: [:new, :create], controller: 'cohorts/copy'
  end

  resources :imports, only: [:index, :show] do
    get :download, on: :member
    get :download_upload, on: :member
  end

  resources :match_logs, only: [:index]
  resources :service_history_logs, only: [:index]
  resources :data_sources do
    resources :uploads, except: [:update, :destroy, :edit]
    resources :non_hmis_uploads, except: [:update, :destroy, :edit]
    resources :custom_imports, controller: 'data_sources/custom_imports'
    resource :api_config
    resource :hmis_import_config
  end
  resources :ad_hoc_data_sources do
    resources :uploads, except: [:edit], controller: 'ad_hoc_data_sources/uploads' do
      get :download, on: :member
    end
    get :download, on: :collection
  end

  resources :organizations, only: [:destroy, :edit, :update] do
    resources :contacts, except: [:show], controller: 'organizations/contacts'
  end
  resources :projects, only: [:edit, :show, :update, :destroy] do
    resources :contacts, except: [:show], controller: 'projects/contacts'
    resources :data_quality_reports, only: [:index, :show] do
      get :support, on: :member
      get :answers, on: :member
    end
  end

  resources :inventories, only: [:edit, :update]
  resources :geography, only: [:edit, :update]
  resources :project_cocs, only: [:edit, :update]

  resources :project_groups, except: [:show] do
    get :maintenance, on: :collection
    post :import, on: :collection
    resources :contacts, except: [:show], controller: 'project_groups/contacts'
    resources :data_quality_reports, only: [:index, :show], controller: 'data_quality_reports_project_group' do
      get :support, on: :member
      get :answers, on: :member
    end
  end

  resources :source_data, only: [:index, :show]

  resources :weather, only: [:index]

  resources :notifications, only: [:show] do
    resources :projects, only: [:show] do
      resources :data_quality_reports, only: [:show] do
        get :support, on: :member
        get :answers, on: :member
      end
    end
    resources :project_groups, only: [:show] do
      resources :data_quality_reports, only: [:show], controller: 'data_quality_reports_project_group' do
        get :support, on: :member
        get :answers, on: :member
      end
    end
  end

  resources :messages, only: [:show, :index] do
    collection do
      get :poll
      post :seen
    end
  end

  namespace :health do
    resources :patients, only: [:index] do
      collection do
        post :detail
      end
    end
    resources :team_patients, only: [:index] do
      collection do
        post :detail
      end
    end
    resources :my_patients, only: [:index]
    namespace :he do
      get :search
      resources :cases do
        resources :locations, except: [:index]
        resources :contacts do
          resources :results
        end
        resources :site_managers
        resources :staff
      end
    end
    resources :document_exports, only: [:show, :create] do
      get :download, on: :member
    end
  end

  namespace :api do
    namespace :health do
      namespace :claims do
        resources :patients, only: [] do
          resources :amount_paid, only: [:index], controller: 'patients/amount_paid'
          resources :claims_volume, only: [:index], controller: 'patients/claims_volume'
          resources :ed_nyu_severity, only: [:index], controller: 'patients/ed_nyu_severity'
          resources :roster, only: [:index], controller: 'patients/roster'
          resources :top_conditions, only: [:index], controller: 'patients/top_conditions'
          resources :top_ip_conditions, only: [:index], controller: 'patients/top_ip_conditions'
          resources :top_providers, only: [:index], controller: 'patients/top_providers'
        end
        resources :amount_paid, only: [:index]
        resources :claims_volume, only: [:index]
        resources :ed_nyu_severity, only: [:index]
        resources :roster, only: [:index]
        resources :top_conditions, only: [:index]
        resources :top_ip_conditions, only: [:index]
        resources :top_providers, only: [:index]
      end
    end
    resources :projects, only: [:none] do
      post :index, on: :collection
    end
    resources :hud_filters, only: [:none] do
      post :index, on: :collection
    end
    resources :reports, only: [:none] do
      put :favorite, on: :member
      put :unfavorite, on: :member
    end
    resources :clients, only: [:show]
  end

  namespace :admin do
    # resolves route clash w/ devise
    resources :users, except: [:show, :new, :create] do
      resource :resend_invitation, only: :create
      resource :recreate_invitation, only: :create
      resource :audit, only: :show
      resource :edit_history, only: :show
      resource :locations, only: :show
      patch :reactivate, on: :member
      member do
        post :unlock
        post :un_expire
        post :confirm
        post :impersonate
      end
      collection do
        post :stop_impersonating
      end
    end

    resources :inbound_api_configurations, only: [:index, :new, :create, :destroy]

    resources :inactive_users, except: [:show, :new, :create] do
      patch :reactivate, on: :member
    end
    resources :account_requests, only: [:index, :edit, :update, :destroy] do
      post :confirm
    end

    resources :roles do
      resources :users, only: [:create, :destroy], controller: 'roles/users'
    end
    resources :groups do
      resources :users, only: [:create, :destroy], controller: 'groups/users'
    end
    resources :agencies
    resource :theme, only: [:edit, :update]
    resource :color, only: [:edit, :update]
    namespace :dashboard do
      resources :imports, only: [:index]
      resources :debug, only: [:index]
    end
    resources :de_duplication, only: [:index] do
      collection do
        patch :update
      end
    end
    resources :links
    namespace :health do
      resources :admin, only: [:index]
      resources :agencies, except: [:show]
      resources :coordination_teams, only: [:index, :create, :update, :destroy]
      resources :team_members, only: [:index, :create, :destroy]
      resources :patients, only: [:index] do
        post :update, on: :collection
      end
      resources :accountable_care_organizations, only: [:index, :create, :edit, :update, :new]
      resources :scheduled_documents
      resources :patient_referrals, only: [:edit, :update] do
        patch :reject
        collection do
          get :review
          get :assigned
          get :rejected
          get :disenrolled
          get :disenrollment_accepted
          post :bulk_assign_agency
          post :bulk_assign_agency_and_care_staff
        end
        post :assign_agency
      end
      resources :agency_patient_referrals, only: [:create, :update] do
        get :claim_buttons
        collection do
          get :review
          get :reviewed
        end
      end
      resources :users, only: [:index] do
        post :update, on: :collection
        resources :agency_users, only: [:new, :create]
      end
      resources :roles, only: [:index, :edit, :update]
    end
    resources :translation_keys, only: [:index, :update]
    resources :translation_text, only: [:update]
    resources :configs, only: [:index] do
      patch :update, on: :collection
    end
    resources :sessions, only: [:index, :destroy]
    resources :data_quality_grades, only: [:index]
    resources :consent_limits, except: [:show]
    resources :missing_grades, only: [:create, :update, :destroy]
    resources :utilization_grades, only: [:create, :update, :destroy]
    namespace :eto_api do
      resources :assessments, only: [:index, :edit, :update]
    end
    resources :available_file_tags, only: [:index, :new, :create, :destroy, :edit, :update]
    resources :administrative_events, only: [:index, :new, :create, :edit, :update, :destroy]
    resources :warehouse_alerts
    resources :public_files, only: [:index, :create, :destroy]
    resources :talentlms

    resources :delayed_jobs, only: [:index, :update, :destroy]
  end
  resource :account, only: [:edit, :update] do
    get :locations, on: :member
  end
  resource :account_email, only: [:edit, :update]
  resource :account_password, only: [:edit, :update]
  resource :account_two_factor, only: [:show, :edit, :update, :destroy] do
    get :remove_device
  end
  resources :account_downloads, only: [:index]

  resources :document_exports, only: [:show, :create] do
    get :download, on: :member
  end

  resources :public_files, only: [:show]
  resources :public_agencies, only: [:index]

  post 'hello-sign' => 'hello_sign#callback'

  unless Rails.env.production?
    resource :style_guide, only: :none do
      get :index
      get :add_goal
      get :add_team_member
      get :alerts
      get :buttons
      get :careplan
      get :client_dashboard
      get :form
      get :health_dashboard
      get :health_team
      get :icon_font
      get :modals
      get :pagination
      get :public_report
      get :public_reports
      get :reports
      get :stimulus_select
      get :tags
      get :system_colors
    end
  end

  namespace :system_status do
    get :operational
    get :cache_status
    get :details
    get :actioncable
    get :ping
    get :exception
  end

  root 'root#index'
end
