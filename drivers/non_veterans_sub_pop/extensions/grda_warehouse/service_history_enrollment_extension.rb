module NonVeteransSubPop::GrdaWarehouse
  module ServiceHistoryEnrollmentExtension
    extend ActiveSupport::Concern

    included do
      scope :non_veterans, -> do
        joins(:client).merge(GrdaWarehouse::Hud::Client.non_veterans)
      end

      scope :non_veteran, -> do
        non_veterans
      end
    end
  end
end
