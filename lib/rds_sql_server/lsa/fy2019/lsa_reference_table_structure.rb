SqlServerBase.connection.execute <<~SQL
  #{File.read('lib/rds_sql_server/lsa/fy2019/LSAReferenceTables.sql')}
SQL

SqlServerBase.connection.execute <<~SQL
  if object_id ('sp_lsaPersonDemographics') is not null drop procedure sp_lsaPersonDemographics
SQL

SqlServerBase.connection.execute <<~SQL
  #{File.read('lib/rds_sql_server/lsa/fy2019/sp_LSAPersonDemographics.sql')}
SQL
