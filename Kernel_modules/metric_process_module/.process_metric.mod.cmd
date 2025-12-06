savedcmd_process_metric.mod := printf '%s\n'   process_metric.o | awk '!x[$$0]++ { print("./"$$0) }' > process_metric.mod
