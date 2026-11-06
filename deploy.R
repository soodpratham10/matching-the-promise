# Deploy the game to shinyapps.io.
# Builds a self-contained bundle (app + engine) in a temporary folder.
# Run from the project root:  source("deploy.R")

bundle <- file.path(tempdir(), "matching-the-promise")
unlink(bundle, recursive = TRUE)
dir.create(file.path(bundle, "r"), recursive = TRUE)

file.copy("app/app.R", bundle)
file.copy(c("r/promise.R", "r/bonds.R", "r/matching.R", "r/immunize.R", "r/storms.R"), file.path(bundle, "r"))

rsconnect::deployApp(bundle, appName = "matching-the-promise", forceUpdate = TRUE)
