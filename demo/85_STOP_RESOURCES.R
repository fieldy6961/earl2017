# ---------------------------------------------------------------------------
# 85 - STOP RESOURCES - DSVM and DoAzureParallel CLUSTER if still running 
# ---------------------------------------------------------------------------

# Install/Load libraries
if (!require("devtools")) install.packages("devtools")
if (!require("digest")) library(digest)
if (!require("AzureSMR")) install_github("Microsoft/AzureSMR")
if (!require("keyring")) install_github("gaborcsardi/keyring")
if (!require("secret")) install.packages("secret")
if (!require("devtools")) install.packages("devtools")
system("tzutil /s \"GMT Standard Time\" ")
if (!require("rAzureBatch")) install_github("Azure/rAzureBatch")
if (!require("doAzureParallel")) install_github("Azure/doAzureParallel")


# Create AzureContext
(sc <- createAzureContext(tenantID = key_get("TID","TID"), 
                          clientID = key_get("CID","CID"), 
                          authKey  = key_get("KEY","KEY")))

# List Resource Groups
(rgs <- azureListRG(sc))
# List Subsciptions
azureListSubscriptions(sc)

# Define variables for DSVM
RESOURCEGROUP <- get_secret("smrsfrg2", vault = mdvaultDir)["RESOURCEGROUP"]
REGION <- get_secret("smrsfrg2", vault = mdvaultDir)["REGION"]
VMNAME <- get_secret("smrsfrg2", vault = mdvaultDir)["VMNAME"]
SUBID <- get_secret("AzKeys", vault = mdvaultDir)["SUBID"]
VMSKU <- "Standard_D13_v2"
DEPLNAME <- "Deploy2"

#------------------------------------------------------
# STOP BATCH CLUSTER
stopCluster(cluster)


#------------------------------------------------------
# STOP VM
(status <- azureVMStatus(sc, RESOURCEGROUP, VMNAME, SUBID,
                       ignore = "N", verbose = FALSE))
if(status == "Provisioning succeeded, VM running") {
azureStopVM(azureActiveContext = sc,
            resourceGroup = RESOURCEGROUP,
            vmName = VMNAME,
            mode = "Async",
            subscriptionID = key_get("azureSubsc","azureSubsc"),
            verbose = FALSE)
}
# Check status of VM periodically to check it has been shutdown
azureVMStatus(sc, RESOURCEGROUP, VMNAME, SUBID,
              ignore = "N", verbose = FALSE)
