# -----------------------------------------------------------------------
# 60 - PUBLISH MODEL AS A REAL-TIME WEB-SERVICE.
# -----------------------------------------------------------------------
# After an algo is selected based on some criterion (let's say AUC, which 
# is a balanced metric that considers both sensitivity and specificity.),
# another parallel execution on different sets of parameters are run - parameter tuning.
source("02_DataConfig.R")

# Install/Load libraries
if (!require("keyring")) install_github("gaborcsardi/keyring")
if (!require("secret")) install.packages("secret")
library("mrsdeploy") # Load the mrsdeploy package
source("01_Credentials.R")


# Read in model from model fitting process
model <- readRDS("model.rds")

#  Create Dataset for testing prediction service
dataObj    <- data_config$url
# NOTE: Extracting the last year, and creating dataframe for prediction
predict.df <- rxDataStep(inData = dataObj, rowSelection = year == 2009 )
rxGetVarInfo(predict.df)

## Define a function to score a dataframe using our model
scoreMortDef <- function(df){
    scores <- rxPredict(model, df, extraVarsToWrite=names(df), predVarNames="Pred")
}

# Test function locally
system.time(
(score <- scoreMortDef( predict.df[1:10,] ))
)

######################################
# Build & Test web-service using model

# Remote Login, a prompt will show up to input user and pwd information
# endpoint <- "http://localhost:12800"  #  Use to test on local host on same machine!

#*************************************
#***** LOGIN TO REMOTE SERVER
# Create a remote login on the server, but without entering the remote session

# Login to a R server using mrsdeploy package
# Can log into either Linux, Windows, SQL Server or Hadoop based R Server instances
REGION <- get_secret("smrsfrg2", vault = mdvaultDir)["REGION"]
VMNAME <- get_secret("smrsfrg2", vault = mdvaultDir)["VMNAME"]
endpoint <- sprintf("http://%s.%s.cloudapp.azure.com:12800", VMNAME, REGION)

# remoteLogin(endpoint, session = FALSE, diff = FALSE)
remoteLogin(endpoint, prompt = "Remote> ",
            session = TRUE, diff = FALSE, commandline = FALSE,
            username = get_secret("smrsfrg2", vault = mdvaultDir)["MRSDEPLOYADMINUSER"],
            password = get_secret("smrsfrg2", vault = mdvaultDir)["MRSDEPLOYADMINPASS"])

# Create service name 
service_name_df <- paste0("scoreMortDef_df")

# Publish the function as a web service to the remote server
api <- publishService(
  service_name_df,
  code = scoreMortDef,
  inputs = list(df = "data.frame"),
  outputs = list(mortScoreDf = "data.frame"),
  model = model,
  v = 'v1.0.0'
)
#deleteService(service_name_df, "v1.0.0")

# Show API capabilities
api$capabilities()


#*****************************************************
# Test Consuming the web service

# Send data frame
# 
system.time({
  mds <- api$scoreMortDef(predict.df[1:200,])
})[3]

head(mortScoreDf <- mds$output("mortScoreDf"))


# Number of records to test with
nrecs <- 200
# Execute scoring web-service Request:Response - 200 records - return output to list
rr_mortScore <- vector("list", nrecs)
system.time({ 
  for (i in 1:nrecs) {
      serviceOut <- api$scoreMortDef(predict.df[i,])
      rr_mortScore[[i]] <- serviceOut$output("mortScoreDf")
  }
})

rr_mortScore[[1]]

## OTHER USEFUL FUNCTIONS
#List all services
(listServices())

# Generate swagger json file and use with autorest etc to import API 
# into application program
cat(api$swagger(), file = "loanPredict.json")
system("cat loanpredict.json")

#Logout
remoteLogout()