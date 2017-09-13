# Data for use
data_config <- list(name=c("Mortgage Default"),
                    #url=file.path(rxOptions()$sampleDataDir,"mortDefaultSmall.xdf"),
                    url=RxXdfData(file.path(rxOptions()$sampleDataDir,"mortDefaultSmall.xdf")),
                    label=c("default"),
                    colOptions=c(FALSE),
                    stringsAsFactors=FALSE)