module Window::Health
  class ParticipationFormSignableDocumentsController < IndividualPatientController
    include WindowClientPathGenerator
    include HealthCareplan
    helper ChaHelper

    before_action :set_client, except: [:signature, :signed]
    before_action :set_patient, except: [:signature, :signed]
    before_action :set_form, except: [:signature, :signed]

    # This supports signing without logging in:
    skip_before_action :authenticate_user!, only: [:signature, :signed]
    skip_before_action :require_some_patient_access!, only: [:signature, :signed]

    def create
      @signers = []
      @signers << { 'email': @patient.current_email, 'name': @patient.name }

      @doc = @form.signable_documents.build(signers: @signers, primary: true, user_id: current_user.id)

      @doc.pdf_content_to_upload = get_pdf

      if @doc.valid?
        @form.class.transaction do
          @doc.save
          @expires_at = Time.now + signature_source.expires_in
          @signature_request = signature_source.create!(
            patient_id: @patient.id,
            careplan_id: @form.id,
            to_email: @patient.current_email,
            to_name: "#{@patient.first_name} #{@patient.last_name}",
            requestor_email: current_user.email,
            requestor_name: current_user.name,
            sent_at: Time.now,
            expires_at: @expires_at,
            signable_document_id: @doc.id
          )
          @doc.make_document_signable!
        end

        flash[:notice] = "Participation form signature requested from #{@doc.signers.map(&:email).join('; ')}"
      else
        flash[:error] = "#{@doc.errors.full_messages.join('. ')}"
      end
      url_params = {client_id: @client.id, form_id: @form.id, id: @doc.id, email: @patient.current_email, hash: @doc.signer_hash(@patient.current_email)}
      url_params[:sign_out] = true if params[:sign_out].present?
      redirect_to polymorphic_path([:signature] + participation_path_generator + [:participation_form_signable_document], url_params)
      # redirect_back fallback_location: client_health_careplans_path(@client)
    end

    def signature
      @state = :valid
      @doc = Health::ParticipationFormSignableDocument.find(params[:id].to_i)
      if current_user.present?
        @doc.update(expires_at: Health::ParticipationFormSignableDocument.patient_expiration_window)
      end
      sign_out(:user) if params[:sign_out].present?

      if @doc.signer_hash(params[:email]) == params[:hash] && ! @doc.expired? && ! @doc.signed?
        @signature_request_url = @doc.signature_request_url(params[:email])
      elsif @doc.signed?
        @state = :signed
      elsif @doc.expired?
        @doc = nil
        @state = :expired
      else
        not_authorized!
        return
      end

    rescue HelloSign::Error, HelloSign::Error::Conflict
      render 'error'
    end

    def signed
      @doc = Health::ParticipationFormSignableDocument.find(params[:id])
      if @doc.signer_hash(params[:email]) == params[:hash] && ! @doc.expired?
        if @doc.signature_request
          signed_at = Time.now
          @doc.signature_request.update(completed_at: signed_at)
        end
      end

      flash[:notice] = 'Thank you. Your Care Participation Form has been signed.'
    end

    private

    def signature_source
      Health::SignatureRequests::ParticipationFormPatientSignatureRequest
    end

    def get_pdf
      pdf = @form.signable_pdf_object
      file_name = 'participation_form'
      @pdf = pdf.to_pdf

    end

    def set_form
      if params[:participation_form_id] == 'new'
        @form = Health::ParticipationForm.create(patient_id: @patient.id, case_manager_id: current_user.id)
      else
        @form = Health::ParticipationForm.find(params[:participation_form_id].to_i)
      end
    end

  end
end
