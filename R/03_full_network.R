## R/03_classify_network.R
## Functions to classify lines into aggregate categories

add_highway_aggr <- function(x, perimeter = NULL) {
  if (is.null(x) || nrow(x) == 0) return(NULL)
  
  if (!is.null(perimeter)) {
    x <- st_transform(x, st_crs(perimeter))
  }
  
  if (!"highway_aggr" %in% names(x)) {
    x <- x |>
      dplyr::mutate(
        highway_aggr = dplyr::case_when(
          highway == "cycleway"      ~ "cycleway",
          highway == "pedestrian"    ~ "pedestrian",
          highway == "living_street" ~ "living street",
          TRUE                       ~ "others"
        )
      )
  }
  
  x
}
