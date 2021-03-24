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
      remove_column m.table_name, 'source_sha256' if column_exists?(m.table_name, 'source_sha256')
    end
  end

  def up
    MODELS.each do |m|
      digest_sql = m.hmis_hash_expression_pgsql(version: '2020')
      add_column m.table_name, 'source_sha256', "bytea GENERATED ALWAYS AS (#{digest_sql}) STORED"
    end
  end
end
