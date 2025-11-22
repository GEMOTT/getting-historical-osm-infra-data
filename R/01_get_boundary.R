## R/01_get_boundaries.R
## Build the city perimeter using osmdata (ONE city only)

build_city_boundary <- function() {
  
  # Make sure data/<city_tag>/ exists
  city_dir <- file.path("data", city_tag)
  if (!dir.exists(city_dir)) dir.create(city_dir, recursive = TRUE)
  
  # 1. Get bounding box for the city
  bbox <- osmdata::getbb(city_boundary_place, format_out = "polygon")
  if (is.null(bbox)) {
    stop("Bounding box not found for: ", city_boundary_place)
  }
  
  # 2. Query OSM for admin boundary (admin_level = 8 = municipality)
  city_boundary <- osmdata::opq(bbox = bbox) |>
    osmdata::add_osm_feature(key = "boundary", value = "administrative") |>
    osmdata::add_osm_feature(
      key   = "name",
      value = city_name,
      value_exact = FALSE
    ) |>
    osmdata::add_osm_feature(key = "admin_level", value = "8") |>
    osmdata::osmdata_sf()
  
  if (is.null(city_boundary$osm_multipolygons)) {
    stop("City boundary not found in OSM for: ", city_name)
  }
  
  # 3. Extract the polygon and clean it
  perim <- city_boundary$osm_multipolygons[1, ] |>
    sf::st_cast("MULTIPOLYGON") |>
    sf::st_make_valid()
  
  # 4. Save to GeoPackage
  out_gpkg <- file.path(city_dir, paste0(city_tag, "_perimeter.gpkg"))
  
  sf::st_write(
    perim,
    out_gpkg,
    layer  = city_tag,
    driver = "GPKG",
    append = FALSE
  )
  
  message("✔ Saved perimeter for ", city_name, " → ", out_gpkg)
  invisible(perim)
}
