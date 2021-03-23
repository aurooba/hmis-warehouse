class AddGeneratedSourceHash < ActiveRecord::Migration[5.2]
  MODELS = HmisCsvTwentyTwenty::Importer::Importer.importable_files.map(&:second) + [
    GrdaWarehouse::Hud::Affiliation,
    GrdaWarehouse::Hud::Disability,
    GrdaWarehouse::Hud::EmploymentEducation,
    GrdaWarehouse::Hud::Enrollment,
    GrdaWarehouse::Hud::EnrollmentCoc,
    GrdaWarehouse::Hud::Exit,
    GrdaWarehouse::Hud::Funder,
    GrdaWarehouse::Hud::HealthAndDv,
    GrdaWarehouse::Hud::IncomeBenefit,
    GrdaWarehouse::Hud::Service,
    GrdaWarehouse::Hud::Inventory,
    GrdaWarehouse::Hud::Organization,
    GrdaWarehouse::Hud::Project,
    GrdaWarehouse::Hud::ProjectCoc,
    GrdaWarehouse::Hud::Assessment,
    GrdaWarehouse::Hud::CurrentLivingSituation,
    GrdaWarehouse::Hud::AssessmentQuestion,
    GrdaWarehouse::Hud::AssessmentResult,
    GrdaWarehouse::Hud::Event,
    GrdaWarehouse::Hud::User,
  ]

  def down
    MODELS.each do |m|
      m.hmis_structure(version: '2020').keys.each do |col|
        next if col == :ExportID

        puts [m.table_name, col].join('.')
        remove_column m.table_name, 'source_sha256' if column_exists?(m.table_name, 'source_sha256')
      end
    end
  end

  def up

    MODELS.each do |m|
      immutable_casts = []
      puts [m.table_name].join('.')

      m.hmis_structure(version: '2020').keys.each do |col|
        next if col == :ExportID

        puts [m.table_name, col].join('.')
        type = m.columns_hash[col.to_s].type
        case m.columns_hash[col.to_s].type
        when :string, :integer, :decimal
          immutable_casts << "coalesce(#{quote_column_name col}::text,'')"
        # when :integer
        #  immutable_casts << "#{quote_column_name col}::text"
        when :date, :datetime
          immutable_casts << "coalesce(extract(epoch from #{quote_column_name col})::text, '')"
        else
          debugger
          puts "Skipping #{m.table_name} #{col} type: #{type}"
        end
      end

      digest_sql = "digest(#{immutable_casts.join('||')}, 'sha256')"
      add_column m.table_name, 'source_sha256', 'bytea' # GENERATED ALWAYS AS (#{digest_sql}) STORED"
    end


  end
end
