# Eliminar todos los cronjobs

crontab -r

# Recrear el cronjob

cd /documentos/host_share/cronjob
go run setup_docker_cronjob.go

# Ver todos los cronjob

crontab -l

si quieres limpiar todos los contenedores:

docker stop $(docker ps -aq)
docker rm $(docker ps -aq)

# ver el log de cronjob

tail -f /documentos/host_share/docker_images/cronjob_docker.log

# Montar carpeta para carpeta compartida

sudo mkdir /mnt/host_home

sudo mount -t virtiofs host_home /mnt/host_home

# Ejecutar el compose de grafana

docker compose -f docker-compose.yml up -d

sudo docker compose down

- Link de grafana
  http://localhost:3000/
