## R/00_setup.R
## Global setup for ONE city

# Packages ---------------------------------------------------------------

pkgs <- c(
  "sf",
  "osmdata",
  "osmextract",
  "dplyr",
  "tmap",
  "stringr",
  "leaflet"
)

invisible(lapply(pkgs, require, character.only = TRUE))

# Options ----------------------------------------------------------------

options(sf_use_s2 = FALSE)

# ----------------------------------------------------------------------
# CITY SETTINGS: change these when you switch to another city
# ----------------------------------------------------------------------

city_name           <- "Montréal"
city_tag            <- "montréal"
city_boundary_place <- "Montréal, Canada"   # used for the boundary (getbb / oe_get)

# Geofabrik (or other) region used by osmextract::oe_get()
# This should be a region that fully contains your city
infra_region <- "Québec"


# OSM snapshot to use by default
snapshot_version <- "170101"

