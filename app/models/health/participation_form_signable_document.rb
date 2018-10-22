# https://app.hellosign.com/api/reference
module Health
  class ParticipationFormSignableDocument < SignableDocument

    def update_careplan_and_health_file!(form)
      # Process patient signature
      if form.signature_on.blank? && self.signed_by?(form.patient.current_email)
        user = User.setup_system_user
        form.update(signature_on: self.signed_on(form.patient.current_email))
        self.signature_request.update(completed_at: form.signature_on)

        #update_health_file_from_hello_sign
        # Need to wait for pdf to be ready
        UpdateHealthFileFromHelloSignJob.
          set(wait: 30.seconds).
          perform_later(self.id)
      end
    end

  end
end
