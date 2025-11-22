## R/05_cycling_network.R
## Build cycling infrastructure networks from the OSM travel network
## created in 02_get_osm_infrastructure.R.
##
## Input:
##   data/<city_tag>/<city_tag>_<version>_lines.gpkg
##
## Output:
##   data/<city_tag>/cycling_network_osmextract_<version>.gpkg
##   data/<city_tag>/cycling_network_osmactive_<version>.gpkg
##
## Both outputs are cycling only networks with:
##   infra_simple = off_road_path / protected_track / painted_lane / shared_footway
##
## The osmactive output also keeps:
##   cycle_segregation (NPT classes)
##   infra5            (same as cycle_segregation but stored as character)

# -------------------------------------------------------------------
# Public wrappers
# -------------------------------------------------------------------

build_cycling_network <- function(
    method   = c("osmextract", "osmactive"),
    version  = snapshot_version,
    city_tag = get("city_tag", envir = .GlobalEnv)
) {
  method <- match.arg(method)
  
  if (method == "osmextract") {
    invisible(build_cycling_network_osmextract(version = version,
                                               city_tag = city_tag))
  } else {
    invisible(build_cycling_network_osmactive(version = version,
                                              city_tag = city_tag))
  }
}

read_cycling_network <- function(
    method   = c("osmextract", "osmactive"),
    version  = snapshot_version,
    city_tag = get("city_tag", envir = .GlobalEnv)
) {
  method <- match.arg(method)
  suffix <- if (method == "osmextract") "osmextract" else "osmactive"
  
  city_dir <- file.path("data", city_tag)
  path     <- file.path(city_dir,
                        paste0("cycling_network_", suffix, "_", version, ".gpkg"))
  
  if (!file.exists(path)) {
    stop(
      "Cycling network file not found: ", path,
      ". Have you run build_cycling_network(method = '", method,
      "', version = '", version, "')?"
    )
  }
  
  sf::st_read(path, quiet = TRUE)
}

# -------------------------------------------------------------------
# 1) Tag based method (transparent osmextract style)
# -------------------------------------------------------------------

build_cycling_network_osmextract <- function(version, city_tag) {
  
  city_dir <- file.path("data", city_tag)
  if (!dir.exists(city_dir)) {
    stop("City directory does not exist: ", city_dir)
  }
  
  lines_path <- file.path(
    city_dir,
    paste0(city_tag, "_", version, "_lines.gpkg")
  )
  
  if (!file.exists(lines_path)) {
    stop(
      "Lines file not found: ", lines_path,
      ". Run get_osm_infrastructure(version = '", version, "') first."
    )
  }
  
  message("→ Reading travel network from: ", lines_path)
  osm_lines <- sf::st_read(lines_path, quiet = TRUE)
  
  # Ensure required tag columns exist (defensive)
  tag_cols <- c(
    "highway",
    "cycleway",
    "cycleway_left",
    "cycleway_right",
    "bicycle",
    "segregated"
  )
  
  missing <- setdiff(tag_cols, names(osm_lines))
  for (nm in missing) {
    osm_lines[[nm]] <- NA_character_
  }
  
  cycle_net <- osm_lines |>
    dplyr::filter(!is.na(highway)) |>
    dplyr::mutate(
      infra_simple = dplyr::case_when(
        # 1) Off road, clearly dedicated cycleways
        highway %in% c("cycleway", "track") ~ "off_road_path",
        
        # 2) Protected tracks wherever they appear
        cycleway %in% c("track", "opposite_track") |
          cycleway_left  %in% c("track", "opposite_track") |
          cycleway_right %in% c("track", "opposite_track") |
          segregated == "yes" ~ "protected_track",
        
        # 3) Painted lanes wherever they appear
        cycleway %in% c("lane", "opposite_lane",
                        "share_busway", "shared_lane") |
          cycleway_left  %in% c("lane", "opposite_lane",
                                "share_busway", "shared_lane") |
          cycleway_right %in% c("lane", "opposite_lane",
                                "share_busway", "shared_lane") ~ "painted_lane",
        
        # 4) Shared footways
        highway %in% c("footway", "path", "pedestrian") &
          bicycle %in% c("designated", "yes") ~ "shared_footway",
        
        # Everything else has no explicit cycling infrastructure
        TRUE ~ NA_character_
      )
    ) |>
    dplyr::filter(!is.na(infra_simple))
  
  if (nrow(cycle_net) == 0) {
    warning("No cycling infrastructure detected in osmextract method for ",
            city_tag, " / ", version)
  }
  
  out_path <- file.path(
    city_dir,
    paste0("cycling_network_osmextract_", version, ".gpkg")
  )
  
  sf::st_write(cycle_net, out_path, driver = "GPKG",
               append = FALSE, quiet = TRUE)
  message("✓ Saved osmextract cycling network to: ", out_path)
  
  invisible(out_path)
}

# -------------------------------------------------------------------
# 2) osmactive method (NPT pipeline)
# -------------------------------------------------------------------

build_cycling_network_osmactive <- function(version, city_tag) {
  
  if (!requireNamespace("osmactive", quietly = TRUE)) {
    stop(
      "The 'osmactive' package is not installed.\n",
      "Install it with: remotes::install_github('nptscot/osmactive')"
    )
  }
  
  city_dir <- file.path("data", city_tag)
  if (!dir.exists(city_dir)) {
    stop("City directory does not exist: ", city_dir)
  }
  
  lines_path <- file.path(
    city_dir,
    paste0(city_tag, "_", version, "_lines.gpkg")
  )
  
  if (!file.exists(lines_path)) {
    stop(
      "Lines file not found: ", lines_path,
      ". Run get_osm_infrastructure(version = '", version, "') first."
    )
  }
  
  message("→ Reading travel network from: ", lines_path)
  osm <- sf::st_read(lines_path, quiet = TRUE)
  
  # This file was created with osmactive::get_travel_network in script 02,
  # so it should already have the schema osmactive expects.
  
  message("→ Running osmactive::get_cycling_network()")
  cycle_net <- osmactive::get_cycling_network(osm)
  
  message("→ Running osmactive::get_driving_network()")
  drive_net <- osmactive::get_driving_network(osm)
  
  message("→ Running osmactive::distance_to_road()")
  cycle_net <- osmactive::distance_to_road(cycle_net, drive_net)
  
  message("→ Running osmactive::classify_cycle_infrastructure()")
  cycle_net <- osmactive::classify_cycle_infrastructure(
    cycle_net,
    include_mixed_traffic = FALSE
  )
  
  # Keep the NPT labels and add our simplified schemes
  cycle_net <- cycle_net |>
    dplyr::mutate(
      # 5 category version, as character
      infra5 = as.character(cycle_segregation),
      # 4 class version, aligned with osmextract
      infra_simple = dplyr::case_when(
        cycle_segregation == "Off Road Path" ~ "off_road_path",
        cycle_segregation %in% c(
          "Segregated Track (wide)",
          "Segregated Track (narrow)"
        ) ~ "protected_track",
        cycle_segregation == "Painted Cycle Lane" ~ "painted_lane",
        cycle_segregation == "Shared Footway" ~ "shared_footway",
        TRUE ~ NA_character_
      )
    ) |>
    dplyr::filter(!is.na(infra_simple))
  
  if (nrow(cycle_net) == 0) {
    warning("No cycling infrastructure retained in osmactive method for ",
            city_tag, " / ", version)
  }
  
  out_path <- file.path(
    city_dir,
    paste0("cycling_network_osmactive_", version, ".gpkg")
  )
  
  sf::st_write(cycle_net, out_path, driver = "GPKG",
               append = FALSE, quiet = TRUE)
  message("✓ Saved osmactive cycling network to: ", out_path)
  
  invisible(out_path)
}

# -------------------------------------------------------------------
# Example use (for README or qmd)
# -------------------------------------------------------------------
#
# source("R/00_setup.R")
# source("R/02_get_osm_infrastructure.R")
# source("R/05_cycling_network.R")
#
# get_osm_infrastructure(version = snapshot_version)
#
# build_cycling_network(method = "osmextract", version = snapshot_version)
# build_cycling_network(method = "osmactive",  version = snapshot_version)
#
# net_oe <- read_cycling_network("osmextract", version = snapshot_version)
# net_oa <- read_cycling_network("osmactive",  version = snapshot_version)
#
# dplyr::count(net_oe, infra_simple)
# dplyr::count(net_oa, infra_simple)
