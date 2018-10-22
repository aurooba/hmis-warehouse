module Health
  class ParticipationForm < HealthBase
    include ArelHelper
    belongs_to :case_manager, class_name: 'User'
    belongs_to :reviewed_by, class_name: 'User'
    belongs_to :patient

    # Patient
    has_many :patient_signature_requests, class_name: Health::SignatureRequests::ParticipationFormPatientSignatureRequest.name
    has_many :patient_signed_signature_requests, -> do
      merge(Health::SignatureRequest.complete)
    end, class_name: Health::SignatureRequests::ParticipationFormPatientSignatureRequest.name
    has_many :patient_signable_documents, through: :patient_signature_requests, source: :signable_document
    has_many :patient_signed_documents, -> do
      merge(Health::ParticipationFormSignableDocument.signed.with_document)
    end, through: :patient_signed_signature_requests, foreign_key: :careplan_id, source: :signable_document
    has_many :patient_signed_health_files, through: :patient_signed_documents, source: :health_files

    has_many :signable_documents, as: :signable
    has_one :primary_signable_document, -> do
      where(signable_documents: {primary: true})
    end, class_name: Health::ParticipationFormSignableDocument.name, as: :signable

    has_one :health_file, class_name: 'Health::ParticipationFormFile', foreign_key: :parent_id, dependent: :destroy
    include HealthFiles

    #validates :signature_on, presence: true
    #validate :file_or_location

    scope :recent, -> { order(signature_on: :desc).limit(1) }
    scope :reviewed, -> { where.not(reviewed_by_id: nil) }
    scope :valid, -> do
      parent_ids = Health::ParticipationFormFile.where.not(parent_id: nil).select(:parent_id).to_sql

      where(
        arel_table[:location].not_in([:nil, '']).
        or(
          arel_table[:id].in(lit(parent_ids))
        )
      )
    end

    scope :signed, -> do
      where.not(signature_on: nil)
    end

    attr_accessor :reviewed_by_supervisor, :file

    before_save :set_reviewer
    private def set_reviewer
      if reviewed_by
        self.reviewer = reviewed_by.name
        self.reviewed_at = DateTime.current
      end
    end

    def signable_pdf_object
      blank_pdf = GrdaWarehouse::PublicFile.where(name: 'patient/participation').
        order(id: :desc).limit(1)&.first
      pdf = CombinePDF.parse(blank_pdf.content)
      return pdf
    end

    def file_or_location
      if health_file.blank? && location.blank?
        errors.add :location, "Please include either a file location or upload."
      end
      if health_file.present? && health_file.invalid?
        errors.add :health_file, health_file.errors.messages.try(:[], :file)&.uniq&.join('; ')
      end
    end
  end
end