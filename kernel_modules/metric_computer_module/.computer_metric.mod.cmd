savedcmd_computer_metric.mod := printf '%s\n'   computer_metric.o | awk '!x[$$0]++ { print("./"$$0) }' > computer_metric.mod
