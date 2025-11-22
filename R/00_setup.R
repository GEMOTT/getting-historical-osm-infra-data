## R/00_setup.R
## Global setup for ONE city: Montréal

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

# Options ---------------------------------------------------------------

options(sf_use_s2 = FALSE)

# ----------------------------------------------------------------------
# CITY SETTINGS: change these ONLY if you switch to another city later
# ----------------------------------------------------------------------

city_name           <- "Montréal"
city_tag            <- "montréal"
city_boundary_place <- "Montréal, Canada"            # for getbb()

# Geofabrik regions used by osmextract
infra_region_2017 <- "Québec"   # 2017 = Quebec province
infra_region_2024 <- "Québec"   # 2024 = whole Canada (old script behaviour)


# ----------------------------------------------------------------------
# Palette for Part 1 maps
# ----------------------------------------------------------------------

pal_highway_aggr <- c(
  "cycleway"      = "#E41A1C",
  "pedestrian"    = "#377EB8",
  "living street" = "#4DAF4A",
  "others"        = "grey"
)

# Tmap defaults ---------------------------------------------------------

tmap::tmap_options(
  frame        = FALSE,
  legend.frame = FALSE,
  bg.color     = NA
)

