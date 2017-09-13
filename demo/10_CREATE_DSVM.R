## CREATE AZURE DSVM

# Install/Load libraries
if(!require("devtools")) install.packages("devtools")
if(!require("digest")) library(digest)
if(!require("AzureSMR")) install_github("Microsoft/AzureSMR")
if(!require("keyring")) devtools::install_github("gaborcsardi/keyring")
if (!require("secret")) install.packages("secret")

# Create AzureContext - Using package Secret to avoid unencrypted keys in Script
mdvaultDir <- file.path("C:/Users/sifield/Documents/rCode/EARL/mdefault", ".vault")
(sc <- createAzureContext(tenantID = get_secret("AzKeys", vault = mdvaultDir)["TID"],
                          clientID = get_secret("AzKeys", vault = mdvaultDir)["CID"],
                          authKey  = get_secret("AzKeys", vault = mdvaultDir)["KEY"] ) )

# List Resource Groups
(rgs <- azureListRG(sc))
# List Subsciptions
azureListSubscriptions(sc)

# Define variables for DSVM - Using package Secret to avoid unencrypted keys in Script
RESOURCEGROUP <- get_secret("smrsfrg2", vault = mdvaultDir)["RESOURCEGROUP"]
REGION        <- get_secret("smrsfrg2", vault = mdvaultDir)["REGION"]
VMNAME        <- get_secret("smrsfrg2", vault = mdvaultDir)["VMNAME"]
VMSKU         <- get_secret("smrsfrg2", vault = mdvaultDir)["VMSKU"]
SUBID         <- get_secret("AzKeys",   vault = mdvaultDir)["SUBID"]
DEPLNAME      <- get_secret("smrsfrg2", vault = mdvaultDir)["DEPLNAME"]

browseURL("https://github.com/Microsoft/microsoft-r/tree/master/rserver-arm-templates", 
          browser = getOption("browser"),
          encodeIfNeeded = FALSE)

browseURL("https://github.com/Azure/azure-quickstart-templates", 
          browser = getOption("browser"),
          encodeIfNeeded = FALSE)

DSVM_ONEBOX_TEMPLATEURI <- "https://raw.githubusercontent.com/Microsoft/microsoft-r/master/rserver-arm-templates/one-box-configuration/windows-dsvm/azuredeploy.json"

PARAMETERJSON <- sprintf('
                         "parameters"                : {
                         "adminUsername"             : {"value": "%s"},
                         "adminPassword"             : {"value": "%s"},
                         "dnsLabelPrefix"            : {"value": "%s"},
                         "vmSku"                     : {"value": "%s"}
                         }
                         ' , get_secret("smrsfrg2", key = fieldyPrivateKey, vault = mdvaultDir)["ADMINUSER"]
                           , get_secret("smrsfrg2", key = fieldyPrivateKey, vault = mdvaultDir)["ADMINPASSWORD"]
                           , VMNAME
                           , VMSKU)

# CREATE RESOURCE GROUP AND DEPLOY NEW DSVM
azureCreateResourceGroup(sc,RESOURCEGROUP,REGION) # Create Resource Group
azureDeployTemplate(sc, deplname = DEPLNAME,
                      templateURL=TEMPLATEURI ,
                      paramJSON = PARAMETERJSON,
                      resourceGroup = RESOURCEGROUP,verbose = TRUE)

# This command can be used to test the status of the VM.  Note it may take a few minutes to boot!
azureVMStatus(sc, RESOURCEGROUP, VMNAME, SUBID,
              ignore = "N", verbose = FALSE)


