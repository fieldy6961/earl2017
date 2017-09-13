# -----------------------------------------------------------------------
# CREATE HELPER FUNCTIONS USED IN SCRIPTS
# -----------------------------------------------------------------------

# FUNCTION : mlProcess
# define a function for binary classification problem.
mlProcess <- function(formula, dataObj, modelName, modelPara) {
  library(RevoScaleR)   # Ensure RevoScaleR library loaded
  set.seed(1)           # Set seed to ensure consistency
  sTime <- proc.time()  # Record start time

  # Set compute-context within the process to local parallel, and use all cores on the node.  
  sysCores <- as.integer(Sys.getenv('NUMBER_OF_PROCESSORS'))
  rxOptions(numCoresToUse = sysCores)
  rxSetComputeContext("localpar")
  
  # Create data for model training
  data.xdf <- RxXdfData(dataObj)
  fit.xdf <- rxDataStep(inData = data.xdf, rowSelection = year %in% 2000:2008 )
   
  data_part  <- c(train=0.7, test=0.3)  ## split data into training/testing sets (70/30%)
  data_split <- rxSplit(fit.xdf,
                        splitByFactor="splitVar",
                        transforms=list(splitVar=
                                        sample(data_factor,
                                               size=.rxNumRows,
                                               replace=TRUE,
                                               prob=data_part)),
                        transformObjects= list(data_part=data_part, 
                                               data_factor=factor(names(data_part),
                                                                  levels=names(data_part)
                                                                  ) 
                                               ) )

  data_train <- data_split[[1]]
  data_test  <- data_split[[2]]

  # train model.
  if(missing(modelPara) ||
     is.null(modelPara) ||
     length(modelPara) == 0) {
          model <- do.call(modelName, list(data=data_train, formula=formula))
       } else {
          model <- do.call(modelName, c(list(data=data_train,
                                             formula=formula), modelPara)) }

  # validate model 
    scores <- rxPredict(model,
                        data_test,
                        extraVarsToWrite=names(data_test),
                        predVarNames="Pred" 
                        )
    depVar <- strsplit(formula, " ~ ")[[1]][1]
    predVar <- names(scores)[1]
    roc <- rxRoc(actualVarName = depVar,
                 predVarNames = predVar,
                 data=scores)
    auc <- rxAuc(roc)

  # # clean up.
  eTime <- unname((proc.time() - sTime)[3]) ## Record overall time for processing this model
  return(list(modelName = modelName , model=model, metric=auc, timing = eTime, form = formula))
}

# FUNCTION : formatResults
# Function: Format output of execution
formatResults <- function(results){
  modelNm   <- unlist(lapply(results, `[[`, "modelName") )
  timing    <- unlist(lapply(results, `[[`, "timing") )
  metric    <- unlist(lapply(results, `[[`, "metric") )
  form      <- unlist(lapply(results, `[[`, "form") )
  resultsDf <- data.frame(modelName = modelNm,
                          timing = timing,
                          metric = metric,
                          form = form)
  resultsDf <- resultsDf[order(resultsDf$metric),]
  return(resultsDf)
}

# FUNCTION : genFormulas
# Create a function to generate a binary matrix of formula combinations
# Note similar approach can be taken to generate parameter sweeps

genFormulas <- function(allvars, targetvar){
  # Function : Creates grid of feature combinations
  genFormGrid <- function(allvars, targetvar){
    # targetvar = the target variable for the formula  
    # allvars = all variables required in formula grid, including dep var 
    
    
    # Get index for target variable
    targetVarIdx <- which(allvars==targetvar)
    # Get dependant variables minus target variable
    varNames  <- allvars[-targetVarIdx]
    # Create named list with element for each variable
    nameLst <- lapply(varNames, names)
    names(nameLst) <- varNames 
    # Create binary matrix with all possible permutations of columns, minus empty formula
    return(expand.grid(lapply(nameLst, c, 0:1))[-1,])
  }
  formGrid <- genFormGrid(allvars, targetvar)
  
  form <- list()
  for(i in 1:nrow(formGrid)){
    ind <- which(formGrid[i, ] == 1)
    form[i] <- paste0(colnames(formGrid)[ind], sep = "+", collapse = "")
    form[i] <- substr(form[i], 1, nchar(form[i])-1) 
    form[i] <- paste0(targetvar, " ~ ", form[i])
  }
  return(form)
}
