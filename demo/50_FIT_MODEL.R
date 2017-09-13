# -----------------------------------------------------------------------------
# 50 FIT MODEL - EXECUTE MULTIPLE MODELS, AND PARAMETER SWEEPS, SELECT BEST FIT
# -----------------------------------------------------------------------------

# -----------------------------------------------------------------------------
# EXECUTE MULTIPLE MODELS, AND PARAMETER SWEEPS, SELECT BEST FIT
# -----------------------------------------------------------------------------
# In this script a learning process that search for an optimal model for 
# solving a classification problem is presented.  To illustrate the convenience 
# of using cloud for parallelizing such a learning process.
# DATA - Demo with Mortgage Default data sample provided with RevoScaleR

# Load Packages
library(RevoScaleR)
library(foreach)

# --------- Create Compute Contexts
## Uncomment the below code to create a local cluster to test locally
## Local Machine Cluster = number of available cores
#library(doParallel)
#numCores <- as.integer(Sys.getenv('NUMBER_OF_PROCESSORS'))
#cluster <- makePSOCKcluster(names=numCores)
#registerDoParallel(cluster)
getDoParName()

source("01_Credentials.R")
source("02_DataConfig.R")
source("03_ModelConfig.R")
source("04_Functions.R")

# -----------------------------------------------------------------------------
# Step 0 - Set up the experiment.
# -----------------------------------------------------------------------------

# Data file referenced for this test - from "02_DataConfig.R"
data_index <- 1

# Get Dependant Variable - from "02_DataConfig.R"
label <- data_config$label[data_index]

# Generate formulas 
# Every column combination via expand.grid, minus label, for this dataset
form <- genFormulas(names(data_config$url), label)

# -----------------------------------------------------------------------------
# Step1 - algorithm selection.
# -----------------------------------------------------------------------------
# "Simplistic Example" - in order to generate a "proxy" parallel workload
# Sweep candidate algorithms and feature combinations to select the best one 
# performance metric such as Area-Under-Curve can be used.

### Passing a dataframe can be costly. Avoid if the dataframe is sizeable! 
### pass a file-reference instead.  Ensure file is availble in storage 
### location visible to all "nodes"
# dataTestDf <- rxDataStep(RxXdfData(file.path(rxOptions()$sampleDataDir, 
#               "mortDefaultSmall.xdf")))
### Passing a local/windows file is optimal for local multi-core clusters on 
### Windows
dataTestLocal  <- file.path(rxOptions()$sampleDataDir,"mortDefaultSmall.xdf")
### For azure batch we need to pass the file-path in the linux file-system, use
### resourceFile
dataTestBatch  <- "/usr/lib64/microsoft-r/3.3/lib64/R/library/RevoScaleR/SampleData/mortDefaultSmall.xdf"

# Define appropriate data source for active compute context
if(getDoParName() == "doParallelSNOW"){dataTest <- dataTestLocal} else 
({if(getDoParName() == "doAzureParallel"){dataTest <- dataTestBatch}})

# Get the number of parallel workers in our parallel backend
# so we can "chunk" and send the work optimally across the workers
(parWork <- getDoParWorkers())
(outerIter  <- length(form))
(innerIter  <- length(model_config$name))
(nTasks    <- outerIter * innerIter) 
(chunkSize <- ceiling(nTasks/ parWork))

# Perform nested foreach loop
## Outer Loop - Passes over every formula combination - 31 formulas
## Inner Loop - Passes over every model type - rxLogit, rxBTree, rxDForest
## %:% collapses loop into a single "loop" for parallel execution
et1 <- system.time(
  results1 <- foreach(f = 1:outerIter,   .combine = "rbind") %:% 
                foreach(i = 1:innerIter, .options.azure = list(chunkSize = chunkSize ),
                                         .combine = "rbind")  %dopar% {
      ## Model processing
               model <- mlProcess(   formula = form[[f]],
                                     dataObj = dataTest,
                                   modelName = model_config$name[i]  )
      ## Model result formatting
      dd <- data.frame(algo =  model$modelName, 
                       metric = model$metric,
                       timing = model$timing,
                       form = model$form,
                       model= I(vector(mode="list", length=1)))
      dd[[1,"model"]] <- model$model
      return(dd)
    } )[3]

# Display and return the results
(results1[, 1:4])

cat("Total compute time for all models : ", sum(results1[, 3]), " secs")
cat("Elapsed time :", et1, " secs")
bestmodel     <- results1[which(results1$metric == max(results1$metric)),]
algo          <- as.character(bestmodel$algo)
para          <- model_config$para[[which(model_config$name == algo)]]
modFormula    <- as.character(bestmodel$form)
modelOptimal1 <- bestmodel$model[[1]]
# save optimal model for deployment
saveRDS(modelOptimal1, file = "./model.rds")


### OPTIONAL
# -----------------------------------------------------------------------------
# Step2 - "parameter" tuning.
# -----------------------------------------------------------------------------
# After an algo is selected based on some criterion 
# e.g. use AUC as a balanced metric that considers both sensitivity and 
#      specificity
# Another parallel execution on different sets of parameters are run - 
# parameter tuning.

# Get the number of parallel workers in our parallel backend
# so we can "chunk" and send the work optimally across the workers
  (parWork <- getDoParWorkers())
   (nTasks <- length(para))
(chunkSize <- ceiling(nTasks/ parWork))

# Sweep parameters of the selected algorithm to find the optimal model.
et2 <- system.time(
  results2 <- foreach(i = 1:nTasks, .options.rsr = list(chunkSize = chunkSize ),
                                  .options.azure = list(chunkSize = chunkSize )) %dopar% {
        ## Model processing
        model <- mlProcess(   formula = modFormula,
                              dataObj = dataTest,
                            modelName = algo,
                            modelPara = para[[i]] )
       return(model) } )[3]

(resOut2 <- formatResults(results2))
sum(resOut2[,2])
cat("Total compute time for all models : ", sum(resOut2[, 2]), " secs")
cat("Elapsed time :", et2, " secs")


# select the optimal model with "best" performance.
metric2    <- lapply(results2, `[[`, "metric")
modelNmOptimal <- resOut2$modelName[which(resOut2$metric == max(resOut2$metric))]
modelOptimal   <- results2[[which(metric2 == max(unlist(metric2)))]][["model"]]
metricOptimal  <- results2[[which(metric2 == max(unlist(metric2)))]][["metric"]]

# save optimal model for deployment
saveRDS(modelOptimal, file="./model.rds")

# Close-out Cluster
stopCluster(cl)
