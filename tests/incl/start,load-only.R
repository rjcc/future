## Record original state
ovars <- ls()
oenvs <- oenvs0 <- Sys.getenv()
oopts0 <- options()

covr_testing <- ("covr" %in% loadedNamespaces())
on_solaris <- grepl("^solaris", R.version$os)

## Default options
oopts <- options(
  warn = 1L,
  mc.cores = 2L,
  future.debug = TRUE,
  ## Reset the following during testing in case
  ## they are set on the test system
  future.availableCores.system = NULL,
  future.availableCores.fallback = NULL
)

## Comment: The below should be set automatically whenever the future package
## is loaded and 'R CMD check' runs.  The below is added in case R is changed
## in the future and we fail to detect 'R CMD check'.
Sys.setenv(R_FUTURE_MAKENODEPSOCK_CONNECTTIMEOUT = 2 * 60)
Sys.setenv(R_FUTURE_MAKENODEPSOCK_TIMEOUT = 2 * 60)
Sys.setenv(R_FUTURE_WAIT_INTERVAL = 0.01) ## 0.01s (instead of default 0.2s)
Sys.setenv(R_FUTURE_MAKENODEPSOCK_SESSIONINFO_PKGS = TRUE)

## Label PSOCK cluster workers (to help troubleshooting)
test_script <- grep("[.]R$", commandArgs(), value = TRUE)[1]
if (is.na(test_script)) test_script <- "UNKNOWN"
worker_label <- sprintf("future/tests/%s:%s:%s:%s", test_script, Sys.info()[["nodename"]], Sys.info()[["user"]], Sys.getpid())
Sys.setenv(R_FUTURE_MAKENODEPSOCK_RSCRIPT_LABEL = worker_label)

## Reset the following during testing in case
## they are set on the test system
oenvs2 <- Sys.unsetenv(c(
  "R_FUTURE_AVAILABLECORES_SYSTEM",
  "R_FUTURE_AVAILABLECORES_FALLBACK",
  ## SGE
  "NSLOTS", "PE_HOSTFILE",
  ## Slurm
  "SLURM_CPUS_PER_TASK",
  ## TORQUE / PBS
  "NCPUS", "PBS_NUM_PPN", "PBS_NODEFILE", "PBS_NP", "PBS_NUM_NODES"
))

oplan <- future::plan()

## Use eager futures by default
future::plan("sequential")

fullTest <- (Sys.getenv("_R_CHECK_FULL_") != "")
isWin32 <- (.Platform$OS.type == "windows" && .Platform$r_arch == "i386")

## Private future functions
.onLoad <- future:::.onLoad
.onAttach <- future:::.onAttach
asIEC <- future:::asIEC
ClusterRegistry <- future:::ClusterRegistry
constant <- future:::constant
detectCores <- future:::detectCores
FutureRegistry <- future:::FutureRegistry
gassign <- future:::gassign
get_future <- future:::get_future
geval <- future:::geval
grmall <- future:::grmall
hpaste <- future:::hpaste
inRCmdCheck <- future:::inRCmdCheck
importParallel <- future:::importParallel
mdebug <- future:::mdebug
mdebugf <- future:::mdebugf
myExternalIP <- future:::myExternalIP
myInternalIP <- future:::myInternalIP
parseCmdArgs <- future:::parseCmdArgs
requestCore <- future:::requestCore
requestNode <- future:::requestNode
requirePackages <- future:::requirePackages
tweakExpression <- future:::tweakExpression
whichIndex <- future:::whichIndex
pid_exists <- future:::pid_exists
isFALSE <- future:::isFALSE
isNA <- future:::isNA

## Local functions for test scripts
printf <- function(...) cat(sprintf(...))
mstr <- function(...) message(paste(capture.output(str(...)), collapse = "\n"))
attachLocally <- function(x, envir = parent.frame()) {
  for (name in names(x)) {
    assign(name, value = x[[name]], envir = envir)
  }
}

supportedStrategies <- function(cores = 1L, excl = c("multiprocess", "cluster"), ...) {
  strategies <- future:::supportedStrategies(...)
  strategies <- setdiff(strategies, excl)
  if (cores == 1L) {
    strategies <- setdiff(strategies, c("multicore", "multisession",
                                        "multiprocess"))
  } else {
    strategies <- setdiff(strategies,
                          c("sequential", "uniprocess", "eager", "lazy"))
  }
  strategies
}

availCores <- min(2L, future::availableCores())
