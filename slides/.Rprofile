# Rendering from slides/ (e.g. the RStudio "Render" button): use the
# repository's renv library, which lives one level up.
local({
  root <- normalizePath("..", mustWork = FALSE)
  if (file.exists(file.path(root, "renv", "activate.R"))) {
    Sys.setenv(RENV_PROJECT = root)
    source(file.path(root, "renv", "activate.R"))
  }
})
