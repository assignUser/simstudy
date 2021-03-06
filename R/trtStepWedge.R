#### Assign treatment for stepped-wedge design ####

#' Assign treatment for stepped-wedge design
#'
#' @param dtName data table
#' @param clustID string representing name of column of cluster level ids
#' @param nWaves number of treatment waves
#' @param lenWaves the number of periods between waves
#' @param startPer the starting period of the first wave
#' @param perName string representing name of column of time periods
#' @param grpName string representing variable name for treatment or
#' exposure group
#' @param lag integer representing length of transition period
#' @param xrName string representing name of the field that 
#' indicates whether the cluster status is in transition status
#' 
#' @return A data.table with the added treatment assignment
#' @seealso \code{\link{trtObserve} \link{trtAssign}}
#' @examples
#' defc <- defData(varname = "ceffect", formula = 0, variance = 0.10, 
#'                 dist = "normal", id = "cluster")
#' defc <- defData(defc, "m", formula = 10, dist = "nonrandom")
#' 
#' # Will generate 3 waves of 4 clusters each - starting 2, 5, and 8
#' 
#' dc <- genData(12, defc)
#' dp <- addPeriods(dc, 12, "cluster")
#' dp <- trtStepWedge(dp, "cluster", nWaves = 3, 
#'                    lenWaves = 3, startPer = 2)
#' dp
#'
#' dp <- addPeriods(dc, 12, "cluster")
#' dp <- trtStepWedge(dp, "cluster", nWaves = 2, 
#'                    lenWaves = 1, startPer = 4, lag = 3)
#' dp
#' 
#' @export
trtStepWedge <- function(dtName, clustID, nWaves, lenWaves, 
                         startPer, perName = "period", grpName = "rx",
                         lag = 0, xrName = "xr") {
  
  # 'declare' vars created in data.table
  
  rx = NULL
  period = NULL
  xr = NULL
  
  #
  
  if (lag == 0) xrName <- "xr"  # override - will be deleted from dd
  
  if (missing(dtName)) {
    stop("Data table argument is missing", call. = FALSE)
  }
  if (grpName %in% names(dtName)) {
    stop("Group name has previously been defined in data table", call. = FALSE)
  }
  if (!(perName %in% names(dtName))) {
    stop("Period name has not been defined in data table", call. = FALSE)
  }
  
  dd <- copy(dtName)
  data.table::setnames(dd, perName, "period")
  
  nClust <- length(dd[, unique(get(clustID))])
  nPer <- length(dd[, unique(period)])
  cPerWave <- nClust/nWaves
  
  if (nClust %% nWaves != 0) {
    
    stop(paste("Cannot create equal size waves with", nClust, "clusters and", 
               nWaves, "waves."))
  }
  
  if ( (nPer) < (startPer + (nWaves - 1) * lenWaves + 1)) {
    
    stop(paste("Design requires", (startPer + (nWaves - 1) * lenWaves + 1),
               "periods but only", nPer, "generated."))
    
  }
  
  startTrt <- rep((0:(nWaves-1))*lenWaves, each = cPerWave) + startPer
  dstart <- data.table::data.table(cid = 1:nClust, startTrt)
  data.table::setnames(dstart, "cid", clustID)
  data.table::setkeyv(dstart, clustID)
  
  data.table::setkeyv(dd, clustID)
  dd <- dd[dstart]
  dd[, xr := ( (period >= startTrt) & ( period < (startTrt + lag) ) ) * 1]
  dd[, rx := ( (startTrt + lag) <= period ) * 1]
  data.table::setnames(dd, c("period", "rx", "xr"), 
                       c(perName, grpName, xrName))
  
  if (lag == 0) dd[, `:=`(xr = NULL)]
  return(dd[])
  
}
