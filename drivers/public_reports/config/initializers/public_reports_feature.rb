# The core app (or other drivers) can check the presence of the
# PublicReports driver with the following code snippet
#
#   do_something if RailsDrivers.loaded.include(:public_reports)
#
# use with caution!
RailsDrivers.loaded << :public_reports
