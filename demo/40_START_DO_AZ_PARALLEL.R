# -----------------------------------------------------------------------------
# 40 - START DoAzureParallel CLUSTER 
# -----------------------------------------------------------------------------

# install the package devtools
if (!require("devtools")) install.packages("devtools")
# Set the timezone - Its not always set on the DSVM
system("tzutil /s \"GMT Standard Time\" ")
# install the doAzureParallel and rAzureBatch package
if (!require("rAzureBatch")) install_github("Azure/rAzureBatch")
if (!require("doAzureParallel")) install_github("Azure/doAzureParallel")

# 0. ONE-TIME ONLY: Create directory for configuration files
 # configDir <- file.path(".doAzureParallel")
 # dir.create(configDir)
 # dir(configDir)

# 1. ONE-TIME ONLY: Generate your credential and cluster configuration files.
  ## generateClusterConfig(".doAzureParallel/cluster.json")
  ## generateCredentialsConfig(".doAzureParallel/credentials.json")

# 2. ONE_TIME ONLY: Fill out your credential config and cluster config files.
#    Enter your Azure Batch Account & Azure Storage keys/account-info into your 
#    credential config ("credentials.json") and configure your cluster in your 
#    cluster config ("cluster.json")

# 3. Set your credentials - you need to give the R session your credentials to 
#    interact with Azure
setCredentials(".doAzureParallel/credentials.json")

# 4. Register the pool. This will create a new pool if your pool hasn't already
#    been provisioned.
cluster <- makeCluster(clusterSetting = ".doAzureParallel/cluster.json", wait = FALSE)
waitForNodesToComplete("sfdazbtch")

# 5. Register the pool as your parallel backend
registerDoAzureParallel(cluster)
# stopCluster(cluster)

# 6. Check that your parallel backend has been registered
getDoParWorkers()

# 7. Run some quick Test jobs 

# Check node names & Working Directory on each node
system.time({
number_of_iterations <- getDoParWorkers()
(results <- foreach(i = 1:number_of_iterations) %dopar% {
  # This code is executed, in parallel, across your cluster.
  c( Sys.info()[4],getwd())
})
})
# Get a list of the pre-installed packages on the cluster 
# - runs on one node - all nodes are identical!
results <- foreach(i = 1:1) %dopar% {
  return(installed.packages())
}
results <- as.data.frame(results)
as.character(results[,1])

# 8. Stop cluster when finnished
#stopCluster(cluster)
