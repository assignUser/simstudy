#### Generate missing data ####

#' Generate missing data
#'
#' @param dtName Name of complete data set
#' @param missDefs Definitions of missingness
#' @param idvars Index variables
#' @param repeated Indicator for longitudinal data
#' @param periodvar Name of variable that contains period
#' @return Missing data matrix indexed by idvars (and period if relevant)
#' @seealso \code{\link{defMiss}}, \code{\link{genObs}}
#' @examples
#' def1 <- defData(varname = "m", dist = "binary", formula = .5)
#' def1 <- defData(def1, "u", dist = "binary", formula = .5)
#' def1 <- defData(def1, "x1", dist="normal", formula = "20*m + 20*u", variance = 2)
#' def1 <- defData(def1, "x2", dist="normal", formula = "20*m + 20*u", variance = 2)
#' def1 <- defData(def1, "x3", dist="normal", formula = "20*m + 20*u", variance = 2)
#'
#' dtAct <- genData(1000, def1)
#'
#' defM <- defMiss(varname = "x1", formula = .15, logit.link = FALSE)
#' defM <- defMiss(defM, varname = "x2", formula = ".05 + m * 0.25", logit.link = FALSE)
#' defM <- defMiss(defM, varname = "x3", formula = ".05 + u * 0.25", logit.link = FALSE)
#' defM <- defMiss(defM, varname = "u", formula = 1, logit.link = FALSE) # not observed
#' defM
#'
#' # Generate missing data matrix
#'
#' missMat <- genMiss(dtAct, defM, idvars = "id")
#' missMat
#'
#' # Generate observed data from actual data and missing data matrix
#'
#' dtObs <- genObs(dtAct, missMat, idvars = "id")
#' dtObs
#' @export

genMiss <- function(dtName, missDefs, idvars,
                    repeated = FALSE, periodvar = "period") {

  # "Declare" vars to avoid R CMD warning
  
  varname <- NULL
  period <- NULL
  baseline <- NULL
  monotonic <- NULL
  fmiss <- NULL
  formula <- NULL
  
  # initialize
  
  includesLags <- FALSE
  
  #

  setkeyv(dtName, idvars)
  tmDefs <- copy(missDefs)

  if (! repeated) {

    dtMiss <- dtName[, c(idvars), with = FALSE]
    # names(dtMiss) <- c(idvars) # removed 2017919 - possible error in CRAN check

    for (i in (1 : nrow(tmDefs))) {
      dtTemp = copy(dtName)
      mat1 <- .genMissDataMat(dtName, dtTemp, idvars, tmDefs[i,])
      vec1 <- mat1[, tmDefs[i, varname], with = FALSE]

      dtMiss <- cbind(dtMiss, vec1)

    }

  } else { # repeated
    
    includesLags <- .checkLags(tmDefs[, formula])

    if (includesLags) {
      
      lags <- .addLags(dtName, tmDefs[, formula])
      
      tmDefs[, formula := lags[[2]]]
      dtName <- lags[[1]]
      
    }
    
    dtMiss <- dtName[, c(idvars, periodvar), with = FALSE]
    colnames <- c(idvars, "period")
    setnames(dtMiss, colnames)

    nPeriods <- dtMiss[,max(period)] + 1

    for (i in (1 : nrow(tmDefs))) {

      if (tmDefs[i, baseline]) {

        dtTemp <- dtName[period == 0]
        mat1 <- .genMissDataMat(dtName[period == 0], dtTemp, idvars, tmDefs[i,])
        vec1 <- addPeriods(mat1, nPeriods, idvars)[, tmDefs[i, varname],
                                                   with=FALSE]

        dtMiss <- cbind(dtMiss, vec1)

      } else { # not just baseline can be missing

        dtTemp = copy(dtName)
        mat1 <- .genMissDataMat(dtName, dtTemp, idvars, tmDefs[i,])
        vec1 <- mat1[, tmDefs[i, varname], with = FALSE]
        dtMiss <- cbind(dtMiss, vec1)

        if (tmDefs[i, monotonic]) { # monotonic missing

          dt.fmiss <- dtMiss[eval(parse(text=tmDefs[i, varname])) == 1, list(fmiss = min(period)), keyby = eval(idvars)]
          data.table::setkeyv(dtMiss, idvars)
          dtMiss <- dt.fmiss[dtMiss]
          dtMiss[period > fmiss, eval(tmDefs[i, varname]) := 1]
          dtMiss[,fmiss := NULL]

        }
      }
    }
  }

  dims <- dim(dtName[, !names(dtMiss), with = FALSE])
  addon <- data.table(matrix(0, nrow = dims[1], ncol = dims[2]))
  names(addon) <- names(dtName[, !names(dtMiss), with = FALSE])

  dtbind <- cbind(dtMiss, addon)
  
  if (includesLags) {
    dtbind[, (lags[[3]]) := NULL]
  }
  
  dtbind[]

}
