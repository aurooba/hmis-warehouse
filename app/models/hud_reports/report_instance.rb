###
# Copyright 2016 - 2020 Green River Data Analysis, LLC
#
# License detail: https://github.com/greenriver/hmis-warehouse/blob/master/LICENSE.md
###

# A HUD Report instance, identified by report name (e.g., report_name: 'CE APR - 2020')
module HudReports
  class ReportInstance < GrdaWarehouseBase
    include ActionView::Helpers::DateHelper
    self.table_name = 'hud_report_instances'

    belongs_to :user
    has_many :report_cells, dependent: :destroy

    def current_status
      case state
      when 'Waiting'
        'Queued to start'
      when 'Started'
        if started_at < 24.hours.ago
          'Failed'
        else
          "#{state} at #{started_at}"
        end
      when 'Completed'
        "#{state} at #{completed_at} in #{distance_of_time_in_words(started_at, completed_at)}"
      else
        'Failed'
      end
    end

    # Mark a question as started
    #
    # @param question [String] the question name (e.g., 'Q1')
    # @param tables [Array<String>] the names of the tables in a question
    def start(question, tables)
      answer(question: question).update(status: 'Started', metadata: {tables: tables})
    end

    # Mark a question as completed
    #
    # @param question [String] the question name (e.g., 'Q1')
    def complete(question)
      answer(question: question).update(status: 'Completed')
    end

    def completed_questions
      report_cells.where(status: 'Completed').pluck(:question)
    end

    def completed?
      state == 'Completed'
    end

    # An answer cell in a question
    #
    # @param question [String] the question name (e.g., 'Q1')
    # @param cell [String] the cell name (e.g, 'B2')
    # @return [ReportCell] the answer cell
    def answer(question:, cell: nil)
      report_cells.
        where(question: question, cell_name: cell, universe: false).
        first_or_create
    end

    # The universe of clients for a question
    #
    # @param question [String] the question name (e.g., 'Q1')
    # @return [ReportCell] the universe cell
    def universe(question)
      report_cells.
        where(question: question, universe: true).
        first_or_create
    end
  end
end
