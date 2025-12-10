#!/bin/bash

###############################################################################
# Script de generación aleatoria de contenedores Docker
# 
# Este script genera 10 contenedores de manera aleatoria de entre 3 imágenes:
# - high-ram-consumer: Contenedor de alto consumo de RAM
# - high-cpu-consumer: Contenedor de alto consumo de CPU
# - low-consumer: Contenedor de bajo consumo
#
# Uso: ./generate_containers.sh
###############################################################################

# Colores para output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Directorio de logs
LOG_DIR="/var/log/docker_containers"
LOG_FILE="${LOG_DIR}/container_generation.log"

# Crear directorio de logs si no existe
mkdir -p "${LOG_DIR}" 2>/dev/null || {
    LOG_DIR="${HOME}/docker_containers_logs"
    LOG_FILE="${LOG_DIR}/container_generation.log"
    mkdir -p "${LOG_DIR}"
}

# Función para logging
log() {
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    echo "[${timestamp}] $1" | tee -a "${LOG_FILE}"
}

# Función para imprimir con color
print_color() {
    local color=$1
    shift
    echo -e "${color}$@${NC}"
}

# Arrays de imágenes disponibles
# Imágenes de alto consumo de recursos
HIGH_CONSUMPTION_IMAGES=(
    "elasticsearch:9.2.2"
    "mongo:latest"
    "mcp/gitlab:latest"
    "rabbitmq:4.1.6-management-alpine"
    "jupyter/base-notebook:x86_64-ubuntu-22.04"
)

# Imágenes de bajo consumo de recursos
LOW_CONSUMPTION_IMAGES=(
    "nginx:trixie-perl"
    "istio/distroless:latest"
    "alpinelinux/docker-cli:latest-s390x"
    "busybox:unstable-uclibc"
    "redis:alpine3.22"
)

# Combinar todas las imágenes
IMAGES=("${HIGH_CONSUMPTION_IMAGES[@]}" "${LOW_CONSUMPTION_IMAGES[@]}")

# Descripciones de categorías
HIGH_DESC="Alto consumo de recursos"
LOW_DESC="Bajo consumo de recursos"

# Función para limpiar contenedores antiguos (opcional)
cleanup_old_containers() {
    print_color "${YELLOW}" "Limpiando contenedores detenidos antiguos..."
    local removed=$(docker container prune -f 2>/dev/null | grep "Total reclaimed space" || echo "0")
    log "Limpieza de contenedores: ${removed}"
}

# Función para generar un contenedor aleatorio
generate_random_container() {
    local index=$1
    
    # Seleccionar imagen aleatoria
    local random_index=$((RANDOM % ${#IMAGES[@]}))
    local selected_image="${IMAGES[$random_index]}"
    
    # Determinar si es de alto o bajo consumo
    local description="${HIGH_DESC}"
    for low_img in "${LOW_CONSUMPTION_IMAGES[@]}"; do
        if [ "${selected_image}" == "${low_img}" ]; then
            description="${LOW_DESC}"
            break
        fi
    done
    
    # Generar nombre único para el contenedor
    local timestamp=$(date +%Y%m%d_%H%M%S)
    local image_name=$(echo "${selected_image}" | tr '/:' '_' | cut -d'_' -f1-2)
    local container_name="${image_name}_${timestamp}_${index}"
    
    print_color "${BLUE}" "[$index/10] Generando contenedor: ${container_name}"
    log "Generando contenedor ${index}: ${container_name} (${description} - ${selected_image})"
    
    # Ejecutar contenedor (algunos requieren configuración especial)
    local docker_cmd="docker run -d --name ${container_name}"
    
    # Configuraciones especiales por imagen
    case "${selected_image}" in
        elasticsearch:*)
            docker_cmd="${docker_cmd} -e discovery.type=single-node -e xpack.security.enabled=false"
            ;;
        mongo:*)
            docker_cmd="${docker_cmd} -e MONGO_INITDB_ROOT_USERNAME=admin -e MONGO_INITDB_ROOT_PASSWORD=password"
            ;;
        rabbitmq:*)
            docker_cmd="${docker_cmd} -e RABBITMQ_DEFAULT_USER=admin -e RABBITMQ_DEFAULT_PASS=password"
            ;;
        redis:*)
            docker_cmd="${docker_cmd}"
            ;;
        jupyter/*)
            docker_cmd="${docker_cmd} -e JUPYTER_ENABLE_LAB=yes"
            ;;
        busybox:*|alpinelinux/*)
            # Para contenedores que no tienen servicio, mantenerlos vivos con sleep
            docker_cmd="${docker_cmd} ${selected_image} sleep infinity"
            ;;
        *)
            docker_cmd="${docker_cmd} ${selected_image}"
            ;;
    esac
    
    # Agregar la imagen si no es busybox o alpinelinux (ya agregadas arriba)
    if [[ ! "${selected_image}" =~ ^(busybox|alpinelinux) ]]; then
        docker_cmd="${docker_cmd} ${selected_image}"
    fi
    
    # Ejecutar contenedor
    if eval ${docker_cmd} > /dev/null 2>&1; then
        print_color "${GREEN}" "  ✓ Contenedor ${container_name} creado exitosamente"
        log "SUCCESS: Contenedor ${container_name} creado (${selected_image})"
        return 0
    else
        print_color "${RED}" "  ✗ Error al crear contenedor ${container_name}"
        log "ERROR: Fallo al crear contenedor ${container_name} (${selected_image})"
        return 1
    fi
}

# Función principal
main() {
    print_color "${GREEN}" "=========================================="
    print_color "${GREEN}" "  Generador de Contenedores Docker"
    print_color "${GREEN}" "=========================================="
    echo
    
    log "=== Inicio de generación de contenedores ==="
    
    # Verificar que Docker esté disponible
    if ! command -v docker &> /dev/null; then
        print_color "${RED}" "Error: Docker no está instalado o no está en el PATH"
        log "ERROR: Docker no disponible"
        exit 1
    fi
    
    # Verificar que las imágenes existan
    print_color "${YELLOW}" "Verificando imágenes Docker..."
    local missing_images=0
    
    print_color "${YELLOW}" "Imágenes de Alto Consumo:"
    for image in "${HIGH_CONSUMPTION_IMAGES[@]}"; do
        if ! docker image inspect "${image}" > /dev/null 2>&1; then
            print_color "${RED}" "  ✗ Imagen ${image} no encontrada"
            log "ERROR: Imagen ${image} no encontrada"
            missing_images=$((missing_images + 1))
        else
            print_color "${GREEN}" "  ✓ ${image}"
        fi
    done
    
    print_color "${YELLOW}" "Imágenes de Bajo Consumo:"
    for image in "${LOW_CONSUMPTION_IMAGES[@]}"; do
        if ! docker image inspect "${image}" > /dev/null 2>&1; then
            print_color "${RED}" "  ✗ Imagen ${image} no encontrada"
            log "ERROR: Imagen ${image} no encontrada"
            missing_images=$((missing_images + 1))
        else
            print_color "${GREEN}" "  ✓ ${image}"
        fi
    done
    
    if [ ${missing_images} -gt 0 ]; then
        print_color "${RED}" "Error: Faltan ${missing_images} imágenes. Por favor, descárgalas primero"
        log "ERROR: Faltan ${missing_images} imágenes"
        exit 1
    fi
    
    echo
    print_color "${YELLOW}" "Generando 10 contenedores aleatorios..."
    echo
    
    # Generar 10 contenedores
    local success_count=0
    local fail_count=0
    
    for i in {1..10}; do
        if generate_random_container "${i}"; then
            success_count=$((success_count + 1))
        else
            fail_count=$((fail_count + 1))
        fi
        
        # Pequeña pausa entre creaciones
        sleep 0.5
    done
    
    echo
    print_color "${GREEN}" "=========================================="
    print_color "${GREEN}" "  Resumen de Generación"
    print_color "${GREEN}" "=========================================="
    print_color "${GREEN}" "Contenedores creados: ${success_count}/10"
    if [ ${fail_count} -gt 0 ]; then
        print_color "${RED}" "Contenedores fallidos: ${fail_count}/10"
    fi
    
    log "=== Fin de generación: ${success_count} exitosos, ${fail_count} fallidos ==="
    
    echo
    print_color "${BLUE}" "Para ver los contenedores activos:"
    print_color "${BLUE}" "  docker ps"
    echo
    print_color "${BLUE}" "Para ver los logs:"
    print_color "${BLUE}" "  cat ${LOG_FILE}"
}

# Ejecutar función principal
main "$@"
