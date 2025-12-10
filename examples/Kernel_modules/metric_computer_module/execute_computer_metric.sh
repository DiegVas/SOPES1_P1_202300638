make # se compila y genera los archivos para instalar
sudo insmod computer_metric.ko # instalar el modulo en kernel

sudo dmesg | tail -n 20 # para ver los logs del kernel


cat /proc/sysinfo # imprime lo escrito en el archivo 

sudo rmmod computer_metric # desinstalar modulo