## R/02_get_osm_infrastructure.R
## Download OSM travel network (all modes) with all active travel tags
## using osmactive::get_travel_network(), and clip to the city perimeter.
##
## Output:
##   data/<city_tag>/<city_tag>_<version>_lines.gpkg

get_osm_infrastructure <- function(version = snapshot_version) {
  
  if (!exists("city_tag") || !exists("city_name") || !exists("infra_region")) {
    stop("Please source('R/00_setup.R') before calling get_osm_infrastructure().")
  }
  
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
  
  # -------------------------------------------------------------------
  # Find perimeter file (same logic as before)
  # -------------------------------------------------------------------
  
  gpkg_files <- list.files(city_dir, pattern = "\\.gpkg$", full.names = TRUE)
  if (length(gpkg_files) == 0) {
    stop("No .gpkg files found in ", city_dir,
         ". Run your boundary script first.")
  }
  
  preferred1 <- file.path(city_dir, paste0(city_tag, "_perimeter.gpkg"))
  preferred2 <- file.path(city_dir, "boundary_city.gpkg")
  
  if (file.exists(preferred1)) {
    perim_path <- preferred1
  } else if (file.exists(preferred2)) {
    perim_path <- preferred2
  } else if (length(gpkg_files) == 1) {
    perim_path <- gpkg_files[1]
  } else {
    stop(
      "Could not automatically identify the perimeter file in ",
      city_dir,
      ". Candidates:\n - ",
      paste(basename(gpkg_files), collapse = "\n - "),
      "\nRename the correct one to '", city_tag, "_perimeter.gpkg'",
      " or 'boundary_city.gpkg'."
    )
  }
  
  message("✓ Using perimeter file: ", perim_path)
  
  layers_info <- sf::st_layers(perim_path)
  layer_name  <- layers_info$name[1]
  
  message("  Using layer: ", layer_name)
  
  perim <- sf::st_read(perim_path, layer = layer_name, quiet = TRUE)
  
  # Transform perimeter to WGS84 for oe_get / get_travel_network
  if (is.na(sf::st_crs(perim))) {
    stop("Perimeter has no CRS. Please define a CRS (likely EPSG:4326) for: ", perim_path)
  }
  if (sf::st_crs(perim)$epsg != 4326) {
    message("  Transforming perimeter CRS to EPSG:4326")
    perim <- sf::st_transform(perim, 4326)
  }
  
  # -------------------------------------------------------------------
  # Download travel network with osmactive (internally uses oe_get + et_active)
  # -------------------------------------------------------------------
  
  out_file <- file.path(
    city_dir,
    paste0(city_tag, "_", version, "_lines.gpkg")
  )
  
  if (file.exists(out_file)) {
    message("↪ Skipping download (exists): ", basename(out_file))
    message("  If you want to refresh, delete the file and rerun get_osm_infrastructure().")
    return(invisible(out_file))
  }
  
  message("→ Downloading travel network with osmactive::get_travel_network()")
  message("  place   = '", infra_region, "'")
  message("  version = '", version, "'")
  
  osm <- tryCatch(
    {
      osmactive::get_travel_network(
        place         = infra_region,
        boundary      = perim,
        boundary_type = "clipsrc",
        version       = version,    # passed through to oe_get
        quiet         = FALSE
      )
    },
    error = function(e) {
      message("  ✖ get_travel_network error: ", e$message)
      return(NULL)
    }
  )
  
  if (is.null(osm) || nrow(osm) == 0) {
    stop("No features returned by get_travel_network for ",
         infra_region, " / ", version)
  }
  
  # Keep only line geometries, just in case
  osm <- osm[
    sf::st_geometry_type(osm$geometry) %in%
      c("LINESTRING", "MULTILINESTRING"),
  ]
  
  if (nrow(osm) == 0) {
    stop("No LINESTRING / MULTILINESTRING features in travel network for ",
         infra_region, " / ", version)
  }
  
  # Just in case the CRS is not WGS84
  if (sf::st_crs(osm)$epsg != 4326) {
    message("  Transforming OSM network CRS to EPSG:4326")
    osm <- sf::st_transform(osm, 4326)
  }
  
  sf::st_write(osm, out_file, driver = "GPKG", append = FALSE, quiet = TRUE)
  message("  ✓ Saved ", basename(out_file), " (", nrow(osm), " features)")
  
  message("✔ Infrastructure extraction completed for ", city_name,
          " (version: ", version, ")")
  
  invisible(out_file)
}
