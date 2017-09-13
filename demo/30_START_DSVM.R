# -----------------------------------------------------------------------------
# 30 - START AZURE DSVM
# -----------------------------------------------------------------------------

# Install/Load libraries
if(!require("devtools")) install.packages("devtools")
if(!require("digest"))   library(digest)
if(!require("AzureSMR")) install_github("Microsoft/AzureSMR")
if(!require("keyring"))  install_github("gaborcsardi/keyring")
if(!require("secret"))   install.packages("secret")

source("01_Credentials.R")

# Create AzureContext - Using package Secret to avoid unencrypted keys in Script
(sc <- createAzureContext(tenantID = get_secret("AzKeys", vault = mdvaultDir)["TID"],
                          clientID = get_secret("AzKeys", vault = mdvaultDir)["CID"],
                          authKey = get_secret("AzKeys", vault = mdvaultDir)["KEY"]))

# Define variables for DSVM - Using package Secret to avoid unencrypted keys 
# in Script
RESOURCEGROUP <- get_secret("smrsfrg2", vault = mdvaultDir)["RESOURCEGROUP"]
REGION <- get_secret("smrsfrg2", vault = mdvaultDir)["REGION"]
VMNAME <- get_secret("smrsfrg2", vault = mdvaultDir)["VMNAME"]
SUBID <- get_secret("AzKeys", vault = mdvaultDir)["SUBID"]

# If the status of the VM is stopped, start the VM
(status <- azureVMStatus(sc, RESOURCEGROUP, VMNAME, SUBID,
              ignore = "N", verbose = FALSE))
if (status == "Provisioning succeeded, VM deallocated") {
  azureStartVM(azureActiveContext = sc, 
               resourceGroup = RESOURCEGROUP, 
               vmName = VMNAME,
               mode = "Async",
               subscriptionID = get_secret("AzKeys", vault = mdvaultDir)["SUBID"],
               verbose = FALSE) }

# Check the status periodically to ensure it has started successfully
azureVMStatus(sc, RESOURCEGROUP, VMNAME, SUBID,
                        ignore = "N", verbose = FALSE)

###  MULTIPLE WAYS OF ACCESS THE DSVM TO WORK
# 1. Remote Desktop
# 2. Jupyter Notebook Service
# 3. R Server mrsdeploy package for remote access
# 4. VisualStudio + R Tool : Workspace (remote) 
#                          : requires some additional configuration  
#                          :  https://blogs.u2u.be/u2u/post/Using-Azure-VMs-as-remote-R-workspaces-in-R-Tools-for-Visual-Studio

# 1. Start a Remote Desktop onto DSVM
rdsCmd <- sprintf("mstsc /v:%s.%s.cloudapp.azure.com /f", VMNAME, REGION)
shell(rdsCmd, wait = FALSE) #  This works for Windows O.S. only. Use alternative
                            #   RDP software for Linux/Mac clients

# 2. Open the Jupyter Notebook service running on DSVM from the local Browser
dsvm_jupyter_url <- sprintf("https://%s.%s.cloudapp.azure.com:9999/", VMNAME, REGION)
browseURL(dsvm_jupyter_url,
          browser = getOption("browser"),
          encodeIfNeeded = FALSE)

# 3. R Server mrsdeploy package
library("mrsdeploy") # Load the mrsdeploy package
# Login to a R server using mrsdeploy package
# Can log into either Linux, Windows, SQL Server or Hadoop based R Server instances
dsvm_mrsdeploy_url <- sprintf("http://%s.%s.cloudapp.azure.com:12800", VMNAME, REGION)
remoteLogin(dsvm_mrsdeploy_url, prompt = "Remote> ",
            session = TRUE, diff = FALSE, commandline = TRUE,
            username = get_secret("smrsfrg2", vault = mdvaultDir)["MRSDEPLOYADMINUSER"],
            password = get_secret("smrsfrg2",  vault = mdvaultDir)["MRSDEPLOYADMINPASS"] )

# Create a few variables in the remote R session
x <- 1:10
y <- 11:20
z <- x + y
print(z) # print z in the remote environment
# Switch back to the local environment
pause()
getRemoteObject("z") # Copy a remote object on the remote session to local
print(z) # Check the object is now in the local session
w <- z # Create a new obect
putLocalObject("w") # Copy the local object up to the remote session
# Switch back to the remote environment
resume()
print(w) # Check the object has been copied to the remote environment
# Pause to switch back to local, 
pause()
getRemoteWorkspace() # pull the entire workspace (environment) back to Local
remoteLogout() # Were finnished. Logout from the remote session

# 4. VisualStudio + R Tool : Workspace (remote) 
# Requires some configuration : See following links - use Remote Desktop session to 
# access the DSVM
 RemoteWorkspaceConfig1_url <- "https://blogs.u2u.be/u2u/post/Using-Azure-VMs-as-remote-R-workspaces-in-R-Tools-for-Visual-Studio"
browseURL(RemoteWorkspaceConfig1_url,
          browser = getOption("browser"),
          encodeIfNeeded = FALSE)
RemoteWorkspaceConfig2_url  <- "https://docs.microsoft.com/en-gb/visualstudio/rtvs/workspaces-remote-setup"
browseURL(RemoteWorkspaceConfig2_url,
          browser = getOption("browser"),
          encodeIfNeeded = FALSE)

###  Demonstrate in Visual Studio - Remote Workspaces


