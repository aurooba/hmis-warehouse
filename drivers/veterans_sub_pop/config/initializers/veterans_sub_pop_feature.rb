# The core app (or other drivers) can check the presence of the
# VeteransSubPop driver with the following code snippet
#
#   do_something if RailsDrivers.loaded.include(:veterans_sub_pop)
#
# use with caution!
RailsDrivers.loaded << :veterans_sub_pop

AvailableSubPopulations.add_sub_population(
  'Veterans',
  :veterans,
  'VeteransSubPop::GrdaWarehouse::WarehouseReports::Dashboard::Veterans',
)

GrdaWarehouse::Census.add_population(
  population: :veterans,
  scope: GrdaWarehouse::ServiceHistoryEnrollment.veterans,
  factory: VeteransSubPop::GrdaWarehouse::Census::VeteransFactory,
)

SubpopulationHistoryScope.add_sub_population(
  :veterans,
  :veterans,
)

Reporting::MonthlyReports::Base.add_available_type(
  :veterans,
  'VeteransSubPop::Reporting::MonthlyReports::Veterans',
)