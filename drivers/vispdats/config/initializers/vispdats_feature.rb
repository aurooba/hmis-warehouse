# The core app (or other drivers) can check the presence of the
# Vispdats driver with the following code snippet
#
#   do_something if RailsDrivers.loaded.include(:vispdats)
#
# use with caution!
RailsDrivers.loaded << :vispdats
