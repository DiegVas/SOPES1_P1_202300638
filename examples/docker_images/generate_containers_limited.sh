#!/bin/bash

###############################################################################
# Script de generación LIMITADA de contenedores Docker
# 
# Este script genera hasta un MÁXIMO de contenedores totales en el sistema
# Si se alcanza el límite, detiene y elimina los más antiguos
#
# Configuración:
# - MAX_CONTAINERS_TOTAL: Límite total de contenedores en el sistema
# - CONTAINERS_TO_GENERATE: Cuántos generar en cada ejecución
###############################################################################

# CONFIGURACIÓN
MAX_CONTAINERS_TOTAL=15  # Límite máximo de contenedores en el sistema
CONTAINERS_TO_GENERATE=5  # Cuántos generar por ejecución
MAX_AGE_MINUTES=30  # Eliminar contenedores más viejos que X minutos

# Colores para output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
MAGENTA='\033[0;35m'
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
HIGH_CONSUMPTION_IMAGES=(
    "mongo:latest"
)

LOW_CONSUMPTION_IMAGES=(
    "nginx:trixie-perl"
    "busybox:unstable-uclibc"
)

# Combinar todas las imágenes
IMAGES=("${HIGH_CONSUMPTION_IMAGES[@]}" "${LOW_CONSUMPTION_IMAGES[@]}")

HIGH_DESC="Alto consumo"
LOW_DESC="Bajo consumo"

# Función para contar contenedores actuales
count_containers() {
    local result=$(docker ps -a 2>/dev/null | grep -E "mongo|nginx|busybox" | wc -l)
    echo "${result}"
}

# Función para limpiar contenedores antiguos
cleanup_old_containers() {
    local current_count=$(count_containers)
    
    if [ ${current_count} -ge ${MAX_CONTAINERS_TOTAL} ]; then
        print_color "${YELLOW}" "⚠️  Límite alcanzado (${current_count}/${MAX_CONTAINERS_TOTAL})"
        log "LÍMITE: ${current_count} contenedores, eliminando los más antiguos..."
        
        # Obtener los contenedores más antiguos
        local to_remove=$((current_count - MAX_CONTAINERS_TOTAL + CONTAINERS_TO_GENERATE))
        
        print_color "${YELLOW}" "Eliminando ${to_remove} contenedores más antiguos..."
        
        docker ps -a --filter "name=mongo\|nginx\|busybox" \
            --format "{{.ID}} {{.CreatedAt}}" | \
            sort -k2 | \
            head -n ${to_remove} | \
            awk '{print $1}' | \
            while read container_id; do
                docker rm -f ${container_id} > /dev/null 2>&1
                print_color "${MAGENTA}" "  ✓ Contenedor ${container_id} eliminado"
                log "CLEANUP: Contenedor ${container_id} eliminado"
            done
    fi
}

# Función para limpiar por edad
cleanup_by_age() {
    print_color "${YELLOW}" "Verificando contenedores por edad... y categoria"
    
    local now=$(date +%s)
    local max_age_seconds=$((MAX_AGE_MINUTES * 60))
    local removed=0
    
    docker ps -a --filter "name=mongo\|nginx\|busybox" \
        --format "{{.ID}} {{.CreatedAt}}" | \
        while read id created_str; do
            # Convertir fecha a timestamp
            local created=$(date -d "$created_str" +%s 2>/dev/null || echo $now)
            local age=$((now - created))
            
            if [ ${age} -gt ${max_age_seconds} ]; then
                docker rm -f ${id} > /dev/null 2>&1
                print_color "${MAGENTA}" "  ✓ Contenedor antiguo ${id} eliminado (edad: $((age/60)) min)"
                log "CLEANUP_AGE: Contenedor ${id} eliminado (${age}s de vida)"
                removed=$((removed + 1))
            fi
        done
    
    if [ ${removed} -gt 0 ]; then
        log "CLEANUP_AGE: ${removed} contenedores eliminados por edad"
    fi
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
    local random_suffix=$((RANDOM % 10000))
    local image_name=$(echo "${selected_image}" | tr '/:' '_' | cut -d'_' -f1-2)
    local container_name="${image_name}_${timestamp}_${random_suffix}"
    
    print_color "${BLUE}" "[$index/${CONTAINERS_TO_GENERATE}] Generando: ${container_name}"
    log "Generando contenedor ${index}: ${container_name} (${description} - ${selected_image})"
    
    # Ejecutar contenedor (configuración especial por imagen)
    local docker_cmd="docker run -d --name ${container_name}"
    
    case "${selected_image}" in
        elasticsearch:*)
            docker_cmd="${docker_cmd} -e discovery.type=single-node -e xpack.security.enabled=false ${selected_image}"
            ;;
        mongo:*)
            docker_cmd="${docker_cmd} -e MONGO_INITDB_ROOT_USERNAME=admin -e MONGO_INITDB_ROOT_PASSWORD=password ${selected_image}"
            ;;
        rabbitmq:*)
            docker_cmd="${docker_cmd} -e RABBITMQ_DEFAULT_USER=admin -e RABBITMQ_DEFAULT_PASS=password ${selected_image}"
            ;;
        jupyter/*)
            docker_cmd="${docker_cmd} -e JUPYTER_ENABLE_LAB=yes ${selected_image}"
            ;;
        busybox:*|alpinelinux/*)
            docker_cmd="${docker_cmd} ${selected_image} sleep infinity"
            ;;
        *)
            docker_cmd="${docker_cmd} ${selected_image}"
            ;;
    esac
    
    # Ejecutar contenedor
    if eval ${docker_cmd} > /dev/null 2>&1; then
        print_color "${GREEN}" "  ✓ Contenedor creado exitosamente"
        log "SUCCESS: Contenedor ${container_name} creado (${selected_image})"
        return 0
    else
        print_color "${RED}" "  ✗ Error al crear contenedor"
        log "ERROR: Fallo al crear contenedor ${container_name} (${selected_image})"
        return 1
    fi
}

# Función principal
main() {
    print_color "${GREEN}" "=========================================="
    print_color "${GREEN}" "  Generador LIMITADO de Contenedores"
    print_color "${GREEN}" "=========================================="
    echo
    
    log "=== Inicio de generación de contenedores ==="
    
    # Verificar Docker
    if ! command -v docker &> /dev/null; then
        print_color "${RED}" "Error: Docker no está instalado"
        log "ERROR: Docker no disponible"
        exit 1
    fi
    
    # Contar contenedores actuales
    local current_count=$(count_containers)
    print_color "${YELLOW}" "Contenedores actuales: ${current_count}/${MAX_CONTAINERS_TOTAL}"
    log "Contenedores actuales: ${current_count}"
    
    # Limpiar por edad primero
    cleanup_by_age
    
    # Limpiar si se alcanzó el límite
    cleanup_old_containers
    
    # Actualizar conteo después de limpieza
    current_count=$(count_containers)
    
    # Verificar si podemos generar más
    local available_space=$((MAX_CONTAINERS_TOTAL - current_count))
    
    if [ ${available_space} -le 0 ]; then
        print_color "${RED}" "⚠️  No se pueden generar más contenedores (límite alcanzado)"
        log "LÍMITE: No se pueden generar más contenedores"
        exit 0
    fi
    
    # Ajustar cantidad a generar si es necesario
    local to_generate=${CONTAINERS_TO_GENERATE}
    if [ ${to_generate} -gt ${available_space} ]; then
        to_generate=${available_space}
        print_color "${YELLOW}" "Ajustando a ${to_generate} contenedores (espacio disponible)"
    fi
    
    echo
    print_color "${YELLOW}" "Generando ${to_generate} contenedores nuevos..."
    echo
    
    # Generar contenedores
    local success_count=0
    local fail_count=0
    
    for i in $(seq 1 ${to_generate}); do
        if generate_random_container "${i}"; then
            success_count=$((success_count + 1))
        else
            fail_count=$((fail_count + 1))
        fi
        sleep 0.3
    done
    
    # Conteo final
    local final_count=$(count_containers)
    
    echo
    print_color "${GREEN}" "=========================================="
    print_color "${GREEN}" "  Resumen de Generación"
    print_color "${GREEN}" "=========================================="
    print_color "${GREEN}" "Contenedores creados: ${success_count}/${to_generate}"
    if [ ${fail_count} -gt 0 ]; then
        print_color "${RED}" "Contenedores fallidos: ${fail_count}"
    fi
    print_color "${BLUE}" "Total en sistema: ${final_count}/${MAX_CONTAINERS_TOTAL}"
    
    log "=== Fin: ${success_count} exitosos, ${fail_count} fallidos, Total: ${final_count} ==="
    
    echo
    print_color "${BLUE}" "Para ver los contenedores: docker ps"
    print_color "${BLUE}" "Para ver estadísticas: docker stats"
}

# Ejecutar función principal
main "$@"
