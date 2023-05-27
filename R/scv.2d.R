#' Function performing two-dimensional decomposition of the squared
#' coefficient of variation (SCV).
#'
#' @param data Data frame containing income data.
#' @param total String specifying the name of the column containing data on
#' total income.
#' @param feature String specifying the name of the column containing
#' information about the feature used for inequality decomposition. If left
#' blank, total income is not decomposed by feature.
#' @param sources Vector containing strings specifying the names of the columns
#' with data on income sources, the sum of which must be equal to total income.
#' The user can specify the same value as in "total." If left blank, total
#' income is not decomposed by income source.
#' @param weights String specifying the name of the column containing population
#' weights.
#'
#' @description
#'
#' @return Data frame containing values of components of SCV.
#' Every column represents a feature, while every row represents an income
#' source. Thus, every value in this data frame represents the contribution of
#' income inequality in i-th income source among population members
#' possessing j-th feature to total income inequality. These values are
#' calculated using the formulas suggested in Garcia-Penalosa & Orgiazzi (2013).
#'
#' @references
#' Garcia-Penalosa, C., & Orgiazzi, E. (2013). Factor Components of Inequality:
#' A Cross-Country Study. Review of Income and Wealth, 59(4), 689-727.
#'
#' @export
#'
#' @examples
#' \dontrun{
#' No decomposition, just SCV of total income.
#' result <- scv.2d(data, "hitotal", weights = "hpopwgt")
#'
#' Decomposition of income inequality by gender.
#' result <- scv.2d(data, "hitotal", "sex", "hitotal", "hpopwgt")
#'
#' Decomposition of income inequality by gender and income source.
#' result <- scv.2d(data, "hitotal", "sex", c("hilabour", "hicapital",
#' "hitransfer"), "hpopwgt")
#' }
scv.2d <- function(data, total, feature = NULL, sources = NULL,
                   weights = NULL){

  # Create population weights if they are not provided.
  if (is.null(weights)) {
    weights <- paste0(total, ".weights")
    data[weights] <- rep(1, nrow(data))
  }

  # Create income source if none is provided.
  if (is.null(sources)){
    sources <- total
  }

  # Create feature if none is provided.
  if (is.null(feature)){
    feature <- paste0(total, ".all")
    data[feature] <- rep("all", nrow(data))
  }

  # Remove unnecessary data.
  data <- data[, c(feature, total, sources, weights)]

  # Remove rows that have missing values.
  data <- data[complete.cases(data),]

  # Stop executing the function if at least one weight is either
  # zero or negative.
  if (!all(data[, weights] > 0)) {
    stop("At least one weight is nonpositive!", call. = FALSE)
  }

  # Identify unique population groups.
  groups <- unique(data[, feature])

  # Create data frame to store the output.
  out <- data.frame(matrix(ncol = 2 * length(groups) + 1, nrow = length(sources)))
  colnames(out) <- c("source", paste0(groups, ".W"), paste0(groups, ".B"))
  out$source <- sources

  # Normalize population weights.
  ovWgt <- data[, weights]
  ovWgt <- ovWgt / sum(ovWgt)

  # Calculation of SCV's components.
  for (i in sources){

    # Share of inequality attributed to a given income source (alpha).
    # Weighted mean and variance of total income.
    tMean <- weighted.mean(data[, total], ovWgt)
    tVar <- (1 / sum(ovWgt)) * sum(ovWgt * (data[, total] - tMean)^2)

    # SCV of total income.
    tSCV <- tVar / (2 * tMean^2)

    # Weighted mean and average of the total population's income from i-th source.
    iMean <- weighted.mean(data[, i], ovWgt)
    iVar <- (1 / sum(ovWgt)) * sum(ovWgt * (data[, i] - iMean)^2)

    # SCV of the given income source.
    iSCV <- iVar / (2 * iMean^2)

    # Correlation between the income source and total income.
    corrMat <- cov.wt(data[, c(i, total)], ovWgt, cor = T)
    corrL <- corrMat$cor[2]

    # Absolute contribution of the given income source to overall inequality.
    alpha <- corrL * (iMean / tMean) * (tSCV * iSCV)^(1 / 2) / iSCV

    for (j in groups){

      # Create a vector of incomes of j-th population group.
      pgr <- data[data[, feature] == j,]

      # Normalize j-th group's population weights.
      gWgt <- pgr[, weights]
      gWgt <- gWgt / sum(gWgt)

      # Weighted average of j-th group's income from i-th source.
      grMean <- weighted.mean(pgr[, i], gWgt)

      # Weighted variance of j-th group's income from i-th source.
      grVar <- (1 / sum(gWgt)) * sum(gWgt * (pgr[, i] - grMean)^2)

      # Within-group component of SCV for i-th income source
      # of j-th population group.
      num <- alpha * (sum(pgr[, weights]) / sum(data[, weights])) *
        (grMean / iMean)^2 * grVar / (2 * grMean^2)
      out[out$source == i, paste0(j, ".W")] <- num

      # Between-group component of SCV for i-th income source
      # of j-th population group.
      num <- alpha * 0.5 * (sum(pgr[, weights]) / sum(data[, weights])) *
        ((grMean / iMean)^2 - 1)
      out[out$source == i, paste0(j, ".B")] <- num
    }
  }
  return(out)
}