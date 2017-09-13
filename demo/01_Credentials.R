## CREDENTIALS
# The scripts use the secret package to avoid storing keys, ID's and passwords in plain text
library(secret)

# Create file-paths and directories to Vault and Secrets
keyDir <- file.path("~", ".ssh")
# The vault directory is stored in the top-level project folder.  When you open the project

# This is referenced as mdvaultDir in the scripts in secret functions.
mdvaultDir <- file.path(".vault")

# Configure - User Key location 
# By default secret will search in "~/." for the id_rsa.pub and id_rsa.pem. 
# If your files are in the same location and named the same there is nothing more to do here
# Otherwise follow the documentation in secret package for modifying the default search path
