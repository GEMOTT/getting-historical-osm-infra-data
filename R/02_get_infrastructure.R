## R/02_get_infrastructure.R
## Download and clip historical OSM lines for ONE city (uses 00_setup.R)

get_osm_infrastructure <- function() {
  
  if (!exists("city_tag") || !exists("city_name")) {
    stop("Please source('R/00_setup.R') before calling get_osm_infrastructure().")
  }
  
  # 1) vectortranslate (same as before)
  my_vectortranslate <- c(
    "-select", "osm_id,highway", 
    "-where",
    "highway IN (
      'living_street','pedestrian','cycleway',
      'motorway','trunk','primary','secondary','tertiary',
      'unclassified','residential',
      'motorway_link','trunk_link','primary_link',
      'secondary_link','tertiary_link',
      'service','track','bus_guideway','escape','raceway','busway'
    )"
  )
  
  # ------------------------------------------------------------------
  # 2) FIND THE BOUNDARY FILE THAT ALREADY EXISTS
  # ------------------------------------------------------------------
  city_dir <- file.path("data", city_tag)
  if (!dir.exists(city_dir)) {
    stop("City directory does not exist: ", city_dir)
  }
  
  # Candidates: any gpkg in data/<city_tag>
  gpkg_files <- list.files(city_dir, pattern = "\\.gpkg$", full.names = TRUE)
  
  if (length(gpkg_files) == 0) {
    stop("No .gpkg files found in ", city_dir,
         ". Run your boundary script first.")
  }
  
  # Preferred name if it exists
  preferred1 <- file.path(city_dir, paste0(city_tag, "_perimeter.gpkg"))
  preferred2 <- file.path(city_dir, "boundary_city.gpkg")
  
  if (file.exists(preferred1)) {
    perim_path <- preferred1
  } else if (file.exists(preferred2)) {
    perim_path <- preferred2
  } else if (length(gpkg_files) == 1) {
    # only one candidate: use it
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
  
  # Figure out layer name automatically
  layers_info <- sf::st_layers(perim_path)
  layer_name  <- layers_info$name[1]  # take first layer
  
  message("  Using layer: ", layer_name)
  
  perim <- sf::st_read(perim_path, layer = layer_name, quiet = TRUE)
  
  if (sf::st_crs(perim)$epsg != 4326) {
    message("  Transforming perimeter CRS to EPSG:4326")
    perim <- sf::st_transform(perim, 4326)
  }
  
  # ------------------------------------------------------------------
  # From here down, keep your existing fetch_and_crop / fetch_and_clip
  # logic (only changing 'perimeter' -> 'perim' if needed).
  # ------------------------------------------------------------------
  
  fetch_and_clip <- function(place_name, version) {
    out_file <- file.path(city_dir,
                          paste0(city_tag, "_", version, "_lines.gpkg"))
    
    if (file.exists(out_file)) {
      message("↪ Skipping (exists): ", basename(out_file))
      return(invisible(NULL))
    }
    
    message("→ oe_get(place = '", place_name,
            "', version = '", version, "')")
    
    dat <- tryCatch(
      {
        osmextract::oe_get(
          place                   = place_name,
          version                 = version,
          vectortranslate_options = my_vectortranslate,
          quiet                   = FALSE
        )
      },
      error = function(e) {
        message("  ✖ oe_get error: ", e$message)
        return(NULL)
      }
    )
    
    if (is.null(dat) || nrow(dat) == 0) {
      message("  ✖ No rows returned for ", place_name, " / ", version)
      return(invisible(NULL))
    }
    
    dat <- dat[
      sf::st_geometry_type(dat$geometry) %in%
        c("LINESTRING", "MULTILINESTRING"), ]
    
    if (nrow(dat) == 0) {
      message("  ✖ No LINESTRING/MULTILINESTRING after filter")
      return(invisible(NULL))
    }
    
    dat <- sf::st_transform(dat, sf::st_crs(perim))
    dat <- suppressMessages(sf::st_intersection(dat, perim))
    
    if (nrow(dat) == 0) {
      message("  ✖ No features after clipping to perimeter")
      return(invisible(NULL))
    }
    
    sf::st_write(dat, out_file, driver = "GPKG", append = FALSE)
    message("  ✓ Saved ", basename(out_file), " (", nrow(dat), " features)")
  }
  
  # Use regions from setup
  fetch_and_clip(infra_region_2017, "170101")
  fetch_and_clip(infra_region_2024, "240101")
  
  message("✔ Infrastructure extraction completed for ", city_name)
}


