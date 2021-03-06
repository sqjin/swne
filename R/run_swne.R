#' Wrapper for running SWNE analysis
#'
#' @param object A Seurat or Pagoda2 object with normalized data
#' @param reduction.use Which dimensional reduction (e.g. PCA, ICA) to use for the tSNE. Default is PCA.
#' @param cells.use Which cells to analyze (default, all cells)
#' @param dims.use Which dimensions to use as input features
#' @param genes.use If set, run the SWNE on this subset of genes (instead of running on a set of reduced dimensions). Not set (NULL) by default
#' @param data.matrix a data matrix (genes x cells) which has been pre-normalized
#' @param batch Vector of batch effects to correct for
#' @param proj.method Method to use to project factors in 2D. Either "sammon" or "umap"
#' @param dist.use Similarity function to use for calculating factor positions (passed to EmbedSWNE).
#'                 Options include pearson (correlation), IC (mutual information), cosine, euclidean.
#' @param distance.matrix If set, runs tSNE on the given distance matrix instead of data matrix (experimental)
#' @param n.cores Number of cores to use (passed to FindNumFactors)
#' @param k Number of NMF factors (passed to RunNMF). If none given, will be derived from FindNumFactors.
#' @param k.range Range of factors for FindNumFactors to iterate over if k is not given
#' @param var.genes vector to specify variable genes. Will infer from Seurat or use full dataset if not given.
#' @param loss loss function to use (passed to RunNMF)
#' @param alpha.exp Increasing alpha.exp increases how much the NMF factors "pull" the samples (passed to EmbedSWNE)
#' @param snn.exp Decreasing snn.exp increases the effect of the similarity matrix on the embedding (passed to EmbedSWNE)
#' @param n.var.genes Number of variable genes to use
#' @param n_pull Maximum number of factors "pulling" on each sample
#' @param genes.embed Genes to add to the SWNE embedding
#' @param hide.factors Hide factors when plotting SWNE embedding
#' @param reduction.name dimensional reduction name, specifies the position in the object$dr list. swne by default
#' @param reduction.key dimensional reduction key, specifies the string before the number for the dimension names. SWNE_ by default
#' @param return.format format to return ("seurat" object or raw "embedding")
#'
#' @return A list of factor (H.coords) and sample coordinates (sample.coords) in 2D
#'
#' @export RunSWNE
#' @rdname RunSWNE
#' @usage NULL
RunSWNE <- function(x, ...) {
  UseMethod("RunSWNE")
}



#' @rdname RunSWNE
#' @method RunSWNE seurat
#' @export
#' @import Seurat

RunSWNE.seurat <- function(object, proj.method = "sammon", reduction.use = "pca", cells.use = NULL, dims.use = NULL, genes.use = NULL,
                           dist.metric = "cosine", distance.matrix = NULL,  n.cores = 8, k, k.range, var.genes,
                           loss = "mse", genes.embed, hide.factors = T, n_pull = 3,
                           alpha.exp = 1.25, # Increase this > 1.0 to move the cells closer to the factors. Values > 2 start to distort the data.
                           snn.exp = 1.0, # Lower this < 1.0 to move similar cells closer to each other
                           reduction.name = "swne", reduction.key = "SWNE_", return.format = c("embedding", "seurat"), ...
){
  if (is.null(dims.use)) {
    if (is.null(k) || missing(k)) {
      dims.use <- 1:20
    } else {
      dims.use <- 1:k
    }
  }
  if (length(x = dims.use) < 2) {
    stop("Cannot perform SWNE on only one dimension, please provide two or more dimensions")
  }
  if (!is.null(x = distance.matrix)) {
    genes.use <- rownames(x = object@data)
  }
  if (is.null(x = genes.use)) {
    data.use <- GetDimReduction(object = object, reduction.type = reduction.use,
                                slot = "cell.embeddings")[, dims.use]
  }
  if (!is.null(x = genes.use)) {
    data.use <- t(PrepDR(object = object, genes.use = genes.use))
  }
  object_norm <- ExtractNormCounts(object, obj.type = "seurat", rescale = F, rescale.method = "log", batch = NULL)

  if (missing(var.genes)) var.genes <- intersect(object@var.genes, rownames(object_norm))
  var.genes <- intersect(var.genes, rownames(object_norm))
  print(paste(length(var.genes), "variable genes to use"))

  if (missing(k)) {
    if (missing(k.range)) k.range <- seq(2,20,2) ## Range of factors to iterate over
    k.res <- FindNumFactors(object_norm[var.genes,], k.range = k.range, n.cores = n.cores, do.plot = F, loss = loss)
    print(paste(k.res$k, "factors")); k <- k.res$k;
  }

  if (k < 3) {
    warning("k must be an integer of 3 or higher")
    k <- 3
  }

  if (missing(genes.embed)) genes.embed <- NULL
  if (is.null(x = distance.matrix)) {
    if(sum(dim(object@snn)) < 2){
      object <- RunPCA(object, pc.genes = var.genes, do.print = F, pcs.compute = min(k,20))
      pc.scores <- t(GetCellEmbeddings(object, reduction.type = reduction.use, dims.use = dims.use))
      snn <- CalcSNN(pc.scores, k = 20, prune.SNN = 1/20)
    } else {
      snn <- object@snn
    }

    swne_embedding <- run_swne(object_norm, var.genes, snn, k, alpha.exp, snn.exp, n_pull, proj.method, dist.metric, genes.embed,
                               loss, n.cores, hide.factors)
  }
  else {
    swne_embedding <- RunSWNE(as.matrix(distance.matrix), proj.method = proj.method, dist.metric = dist.metric, n.cores = n.cores, k = k,
                              k.range = k.range, var.genes = var.genes, loss = loss, genes.embed = genes.embed,
                              hide.factors = hide.factors, n_pull = n_pull, alpha.exp = alpha.exp, snn.exp = snn.exp)
  }

  if(return.format == "embedding"){
    return(swne_embedding)
  } else if(return.format == "seurat"){
    object <- SetDimReduction(object = object, reduction.type = reduction.name,
                              slot = "cell.embeddings", new.data = as.matrix(swne_embedding$sample.coords))
    object <- SetDimReduction(object = object, reduction.type = reduction.name,
                              slot = "key", new.data = reduction.key)
    parameters.to.store <- as.list(environment(), all = TRUE)[names(formals("RunSWNE"))]
    object <- SetCalcParams(object = object, calculation = "RunSWNE",
                            ... = parameters.to.store)
    if (!is.null(GetCalcParam(object = object, calculation = "RunSWNE",
                              parameter = "genes.use"))) {
      object@calc.params$RunSWNE$genes.use <- colnames(data.use)
      object@calc.params$RunSWNE$cells.use <- rownames(data.use)
    }
    return(object)
  }
}



#' @rdname RunSWNE
#' @method RunSWNE Pagoda2
#' @export
#'
RunSWNE.Pagoda2 <- function(object, proj.method = "sammon", dist.metric = "cosine", n.cores = 8, k, k.range, var.genes,
                            loss = "mse", genes.embed, hide.factors = T, n_pull = 3, n.var.genes = 3000,
                            alpha.exp = 1.25, # Increase this > 1.0 to move the cells closer to the factors. Values > 2 start to distort the data.
                            snn.exp = 1.0 # Lower this < 1.0 to move similar cells closer to each other
){
  object_norm <- ExtractNormCounts(object, obj.type = "pagoda2", rescale = F, rescale.method = "log", batch = NULL)

  if (missing(var.genes)) var.genes <- rownames(p2$misc$varinfo[order(p2$misc$varinfo$lp),])[1:n.var.genes]
  var.genes <- intersect(var.genes, rownames(object_norm))
  print(paste(length(var.genes), "variable genes to use"))

  if (missing(k)) {
    if (missing(k.range)) k.range <- seq(2,20,2) ## Range of factors to iterate over
    k.res <- FindNumFactors(object_norm[var.genes,], k.range = k.range, n.cores = n.cores, do.plot = F, loss = loss)
    print(paste(k.res$k, "factors")); k <- k.res$k;
  }

  if (k < 3) {
    warning("k must be an integer of 3 or higher")
    k <- 3
  }

  object$calculatePcaReduction(nPcs = max(k,20), odgenes = var.genes)
  pc.scores <- t(object$reductions$PCA[,1:k])
  snn <- CalcSNN(pc.scores, k = 20, prune.SNN = 1/20)

  if (missing(genes.embed)) genes.embed <- NULL
  run_swne(object_norm, var.genes, snn, k, alpha.exp, snn.exp, n_pull, proj.method, dist.metric, genes.embed,
           loss, n.cores, hide.factors)
}



#' @rdname RunSWNE
#' @method RunSWNE dgCMatrix
#' @export
RunSWNE.dgCMatrix <- function(data.matrix, proj.method = "sammon", dist.metric = "cosine", n.cores = 3, k, k.range,
                              var.genes = rownames(data.matrix), loss = "mse", genes.embed, hide.factors = T, n_pull = 3,
                              alpha.exp = 1.25, # Increase this > 1.0 to move the cells closer to the factors. Values > 2 start to distort the data.
                              snn.exp = 1.0 # Lower this < 1.0 to move similar cells closer to each other
){
  print(paste(length(var.genes), "variable genes"))
  if (missing(k)) {
    if (missing(k.range)) k.range <- seq(2,20,2) ## Range of factors to iterate over
    k.res <- FindNumFactors(data.matrix[var.genes,], k.range = k.range, n.cores = n.cores, do.plot = F, loss = loss)
    print(paste(k.res$k, "factors")); k <- k.res$k;
  }

  if (k < 3) {
    warning("k must be an integer of 3 or higher")
    k <- 3
  }

  pca.res <- irlba::irlba(t(data.matrix[var.genes,]), nv = max(k,20), center = Matrix::rowMeans(data.matrix[var.genes,]))
  pc.scores <- t(pca.res$u); colnames(pc.scores) <- colnames(data.matrix);
  snn <- CalcSNN(pc.scores, k = 20, prune.SNN = 1/20)

  if (missing(genes.embed)) genes.embed <- NULL
  run_swne(data.matrix, var.genes, snn, k, alpha.exp, snn.exp, n_pull, proj.method, dist.metric, genes.embed,
           loss, n.cores, hide.factors)
}



#' @rdname RunSWNE
#' @method RunSWNE matrix
#' @export
RunSWNE.matrix <- function(data.matrix, proj.method = "sammon", dist.metric = "cosine", n.cores = 3, k, k.range,
                           var.genes = rownames(data.matrix), loss = "mse", genes.embed, hide.factors = T, n_pull = 3,
                           alpha.exp = 1.25, # Increase this > 1.0 to move the cells closer to the factors. Values > 2 start to distort the data.
                           snn.exp = 1.0 # Lower this < 1.0 to move similar cells closer to each other
){
  data.matrix <- as(data.matrix, "dgCMatrix")
  RunSWNE.dgCMatrix(data.matrix, proj.method = proj.method, dist.metric = dist.metric, n.cores = n.cores, k = k,
                    k.range = k.range, var.genes = var.genes, loss = loss, genes.embed = genes.embed,
                    hide.factors = hide.factors, n_pull = n_pull, alpha.exp = alpha.exp, snn.exp = snn.exp)
}



#' @rdname RunSWNE
#' @method RunSWNE dgTMatrix
#' @export
RunSWNE.dgTMatrix <- function(data.matrix, proj.method = "sammon", dist.metric = "cosine", n.cores = 3, k, k.range,
                              var.genes = rownames(data.matrix), loss = "mse", genes.embed, hide.factors = T, n_pull = 3,
                              alpha.exp = 1.25, # Increase this > 1.0 to move the cells closer to the factors. Values > 2 start to distort the data.
                              snn.exp = 1.0 # Lower this < 1.0 to move similar cells closer to each other
){
  data.matrix <- as(data.matrix, "dgCMatrix")
  RunSWNE.dgCMatrix(data.matrix, proj.method = proj.method, dist.metric = dist.metric, n.cores = n.cores, k = k,
                    k.range = k.range, var.genes = var.genes, loss = loss, genes.embed = genes.embed,
                    hide.factors = hide.factors, n_pull = n_pull, alpha.exp = alpha.exp, snn.exp = snn.exp)
}



## Helper function for running SWNE
run_swne <- function(norm_counts, var.genes, snn, k, alpha.exp, snn.exp, n_pull, proj.method, dist.metric,
                     genes.embed, loss, n.cores, hide.factors) {
  nmf.res <- RunNMF(norm_counts[var.genes,], k = k, init = "ica", n.cores = n.cores, loss = loss)
  nmf.scores <- nmf.res$H
  swne_embedding <- EmbedSWNE(nmf.scores, snn, alpha.exp = alpha.exp, snn.exp = snn.exp,
                              n_pull = n_pull, proj.method = proj.method,
                              dist.use = dist.metric)

  if (!is.null(genes.embed)) {
    genes.embed <- intersect(genes.embed, rownames(norm_counts))
    nmf.loadings <- ProjectFeatures(norm_counts, nmf.scores, loss = loss, n.cores = n.cores)
    swne_embedding <- EmbedFeatures(swne_embedding, nmf.loadings, genes.embed, n_pull = n_pull)
  }
  if (hide.factors) swne_embedding$H.coords$name <- ""

  return(swne_embedding)
}

##Internal Functions from Seurat (version 2.3)
# Set CalcParam information
#
# @param object      A Seurat object
# @param calculation The name of the calculation that was done
# @param time store time of calculation as well
# @param ...  Parameters for the calculation
#
# @return object with the calc.param slot modified to either append this
# calculation or replace the previous instance of calculation with
# a new list of parameters
#
SetCalcParams <- function(object, calculation, time = TRUE, ...) {
  object@calc.params[calculation] <- list(...)
  object@calc.params[[calculation]]$object <- NULL
  object@calc.params[[calculation]]$object2 <- NULL
  if(time) {
    object@calc.params[[calculation]]$time <- Sys.time()
  }
  return(object)
}

# Get CalcParam information
#
# @param object      A Seurat object
# @param calculation The name of the calculation that was done
# @param parameter  Parameter for the calculation to pull
#
# @return parameter value for given calculation
#
GetCalcParam <- function(object, calculation, parameter){
  if(parameter == "time"){
    return(object@calc.params[[calculation]][parameter][[1]])
  }
  return(unname(unlist(object@calc.params[[calculation]][parameter])))
}

# Set a default value if an object is null
#
# @param x An object to set if it's null
# @param default The value to provide if x is null
#
# @return default if x is null, else x
#
SetIfNull <- function(x, default) {
  if(is.null(x = x)){
    return(default)
  } else {
    return(x)
  }
}

# Prep data for dimensional reduction
#
# Common checks and preparatory steps before running certain dimensional
# reduction techniques
#
# @param object        Seurat object
# @param genes.use     Genes to use as input for the dimensional reduction technique.
#                      Default is object@@var.genes
# @param dims.compute  Number of dimensions to compute
# @param use.imputed   Whether to run the dimensional reduction on imputed values
# @param assay.type Assay to scale data for. Default is RNA. Can be changed for multimodal analysis

PrepDR <- function(
  object,
  genes.use = NULL,
  use.imputed = FALSE,
  assay.type="RNA"
) {
  if (length(object@var.genes) == 0 && is.null(x = genes.use)) {
    stop("Variable genes haven't been set. Run MeanVarPlot() or provide a vector
          of genes names in genes.use and retry.")
  }
  if (use.imputed) {
    data.use <- t(x = scale(x = t(x = object@imputed)))
  } else {
    data.use <- GetAssayData(object, assay.type = assay.type,slot = "scale.data")
  }
  genes.use <- SetIfNull(x = genes.use, default = object@var.genes)
  genes.use <- unique(x = genes.use[genes.use %in% rownames(x = data.use)])
  genes.var <- apply(X = data.use[genes.use, ], MARGIN = 1, FUN = var)
  genes.use <- genes.use[genes.var > 0]
  genes.use <- genes.use[!is.na(x = genes.use)]
  data.use <- data.use[genes.use, ]
  return(data.use)
}
