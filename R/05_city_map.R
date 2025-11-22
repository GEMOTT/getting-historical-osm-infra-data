## R/04_city_maps.R
## Read files and create tmap maps for ONE city and ONE version

# ---------------------------------------------------------------------
# Read perimeter
# ---------------------------------------------------------------------
read_perimeter <- function() {
  perim_path <- file.path("data", city_tag, paste0(city_tag, "_perimeter.gpkg"))
  if (!file.exists(perim_path)) {
    stop("Perimeter file not found: ", perim_path)
  }
  
  sf::st_read(perim_path, quiet = TRUE) |>
    sf::st_transform(4326)
}

# ---------------------------------------------------------------------
# Read lines for a specific version
# ---------------------------------------------------------------------
read_infra <- function(version) {
  gpkg <- file.path("data", city_tag, paste0(city_tag, "_", version, "_lines.gpkg"))
  lyr  <- paste0(city_tag, "_", version, "_lines")
  
  if (!file.exists(gpkg)) {
    warning("Lines file not found for version ", version)
    return(NULL)
  }
  
  tryCatch(
    sf::st_read(gpkg, layer = lyr, quiet = TRUE),
    error = function(e) NULL
  )
}

# ---------------------------------------------------------------------
# Build a single map for ONE snapshot (version)
# ---------------------------------------------------------------------
## R/06_city_map.R (for example)
## One plotting function, three modes:
## - "full"            : full travel network
## - "cycling_tag"     : cycling infra from tag rules (osmextract style)
## - "cycling_osmactive": cycling infra from osmactive classification

## R/06_city_map.R

make_city_map_tm <- function(
    mode       = c("full", "cycling_tag", "cycling_osmactive"),
    version    = snapshot_version,
    city_tag   = get("city_tag", envir = .GlobalEnv),
    city_name  = NULL,
    year_label = NULL
) {
  mode <- match.arg(mode)
  
  city_dir <- file.path("data", city_tag)
  
  # ------------------------------------------------------------------
  # 1) Choose data source depending on mode
  # ------------------------------------------------------------------
  if (mode == "full") {
    
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
    
    dat <- sf::st_read(lines_path, quiet = TRUE)
    
    # Palette and aggregation for the first map
    pal_highway_aggr <- c(
      "cycleway"      = "#E41A1C",
      "pedestrian"    = "#377EB8",
      "living street" = "#4DAF4A",
      "others"        = "grey"
    )
    
    # Create aggregated variable with exactly these four labels
    dat <- dat |>
      dplyr::mutate(
        highway_aggr = dplyr::case_when(
          highway %in% c("cycleway", "track")     ~ "cycleway",
          highway %in% "pedestrian"               ~ "pedestrian",
          highway %in% "living_street"            ~ "living street",
          TRUE                                    ~ "others"
        )
      )
    
    map_var      <- "highway_aggr"
    legend_title <- NULL
    pal          <- pal_highway_aggr
    
  } else if (mode == "cycling_tag") {
    
    dat <- read_cycling_network(
      method   = "osmextract",
      version  = version,
      city_tag = city_tag
    )
    
    map_var      <- "infra_simple"
    legend_title <- "Cycling infrastructure\n(tag based)"
    
    pal <- c(
      "off_road_path"   = "#1b9e77",
      "protected_track" = "#7570b3",
      "painted_lane"    = "#d95f02",
      "shared_footway"  = "#e7298a"
    )
    
  } else if (mode == "cycling_osmactive") {
    
    dat <- read_cycling_network(
      method   = "osmactive",
      version  = version,
      city_tag = city_tag
    )
    
    # Show the 4 common classes, for easy comparison
    map_var      <- "infra_simple"
    legend_title <- "Cycling infrastructure\n(osmactive)"
    
    pal <- c(
      "off_road_path"   = "#1b9e77",
      "protected_track" = "#7570b3",
      "painted_lane"    = "#d95f02",
      "shared_footway"  = "#e7298a"
    )
  }
  
  # ------------------------------------------------------------------
  # 2) Title defaults
  # ------------------------------------------------------------------
  if (is.null(city_name)) {
    city_name <- city_tag
  }
  if (is.null(year_label)) {
    year_label <- version
  }
  
  title_text <- paste0(city_name, " ", year_label)
  
  # ------------------------------------------------------------------
  # 3) Build tmap object
  # ------------------------------------------------------------------
  tmap::tm_shape(dat) +
    tmap::tm_lines(
      col       = map_var,
      lwd       = 1,
      alpha     = 0.8,
      col.scale = tmap::tm_scale_categorical(values = pal),
      col.legend = tmap::tm_legend(title = legend_title)
    ) +
    tmap::tm_title(
      title_text,
      position = "top",
      size     = 1,
      fontface = "bold"
    ) +
    tmap::tm_layout(
      legend.outside  = FALSE,
      legend.position = c("left", "top"),
      frame           = FALSE
    )
}

plot_city_map_tm <- function(
    mode       = c("full", "cycling_tag", "cycling_osmactive"),
    version    = snapshot_version,
    city_name  = NULL,
    year_label = NULL
) {
  mode <- match.arg(mode)
  tmap::tmap_mode("plot")
  m <- make_city_map_tm(
    mode       = mode,
    version    = version,
    city_name  = city_name,
    year_label = year_label
  )
  print(m)
}



