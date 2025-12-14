# Eliminar todos los cronjobs

crontab -r

# Recrear el cronjob

cd /documentos/host_share/cronjob
go run setup_docker_cronjob.go

# Ver todos los cronjob

crontab -l

# Detener todos los daemons y cronjobs

# 1. Eliminar todos los cronjobs

crontab -r

# 2. Detener el daemon principal (main)

pkill -f "/mnt/host_home/main"

# O si usaste sudo

sudo pkill -f "/mnt/host_home/main"

# 3. Detener el script de generación de contenedores

pkill -f "generate_containers_limited.sh"

# 4. Verificar que se detuvieron

ps aux | grep -E "main|generate_containers"

# Detener SOLO la generación de contenedores (sin detener main.go)

# 1. Eliminar el cronjob de generación (usar sudo si fue creado por root)

sudo crontab -l | grep -v "generate_containers_limited.sh" | sudo crontab -

# O si es tu crontab

crontab -l | grep -v "generate_containers_limited.sh" | crontab -

# 2. Matar TODOS los procesos del script (IMPORTANTE: usar sudo con -9)

sudo pkill -9 -f "generate_containers_limited.sh"

# 3. Verificar que se detuvo

ps aux | grep generate_containers
sudo crontab -l

si quieres limpiar todos los contenedores:

docker stop $(docker ps -aq)
docker rm $(docker ps -aq)

docker system prune -a --volumes -f # Limpiar TODO Docker (contenedores, imágenes, volúmenes, redes, cache)

# ver el log de cronjob

tail -f /documentos/host_share/docker_images/cronjob_docker.log

# Montar carpeta para carpeta compartida

sudo mount -t virtiofs host_home /mnt/host_home

cd /mnt/host_home

# ver el log de cronjob

# Solucionar error de kernel headers (si da error al compilar módulos)

# Compilar todo el proyecto (módulos del kernel + Go)

./build.sh

# Verificar que los módulos del kernel se cargaron correctamente

lsmod | grep -E "process_metric|computer_metric"
ls -l /proc/sysinfo_so1_202300638
ls -l /proc/continfo_so1_202300638

# Si los archivos proc no existen, recargar módulos manualmente

sudo rmmod process_metric 2>/dev/null
sudo rmmod computer_metric 2>/dev/null
sudo insmod kernel_modules/metric_computer_module/computer_metric.ko
sudo insmod kernel_modules/metric_process_module/process_metric.ko
ls -l /proc/sysinfo_so1_202300638
ls -l /proc/continfo_so1_202300638

# Verificar que Docker Compose funciona (antes de ejecutar main)

docker compose -f connexionDB/docker-compose.yml config
docker compose -f connexionDB/docker-compose.yml up -d

# Ejecutar el compose de grafana

docker compose -f docker-compose.yml up -d

sudo docker compose down

- Link de grafana
  http://localhost:3000/

# Leer información del sistema

cat /proc/sysinfo_so1_202300638

# Leer información de procesos

cat /proc/continfo_so1_202300638

# Seguir logs en tiempo real

tail -f docker_images/cronjob_docker.log
