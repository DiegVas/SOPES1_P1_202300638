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
MIN_HIGH_CONSUMPTION=2   # MÍNIMO OBLIGATORIO de contenedores de alto consumo
MIN_LOW_CONSUMPTION=3    # MÍNIMO OBLIGATORIO de contenedores de bajo consumo
MAX_CONTAINERS_TOTAL=15  # Máximo TOTAL de contenedores en el sistema
MAX_HIGH_CONSUMPTION=10  # Máximo de contenedores de alto consumo
MAX_LOW_CONSUMPTION=13   # Máximo de contenedores de bajo consumo
CONTAINERS_TO_GENERATE=10 # Cuántos generar por ejecución
CONTINUOUS_MODE=true     # Modo continuo (true/false)
GENERATION_INTERVAL=60   # Intervalo en segundos entre generaciones (1 minuto)

# Ruta a la base de datos SQLite
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DB_PATH="${SCRIPT_DIR}/../containers.db"

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

# Función para insertar en la base de datos
insert_container_to_db() {
    local container_id=$1
    local container_name=$2
    local image_name=$3
    local status=$4
    local timestamp=$(date +%s)000  # Convertir a milisegundos
    
    if [ -f "${DB_PATH}" ]; then
        # Verificar permisos de escritura antes de intentar
        if [ ! -w "${DB_PATH}" ]; then
            chmod 666 "${DB_PATH}" 2>/dev/null || log "DB WARNING: No se pueden cambiar permisos de ${DB_PATH}"
        fi
        
        sqlite3 "${DB_PATH}" "INSERT OR IGNORE INTO containers (container_id, container_name, image_name, status, created_at) VALUES ('${container_id}', '${container_name}', '${image_name}', '${status}', ${timestamp});" 2>/dev/null
        if [ $? -eq 0 ]; then
            log "DB: Contenedor ${container_name} registrado en base de datos"
        else
            log "DB ERROR: No se pudo registrar contenedor ${container_name}"
        fi
    else
        log "DB WARNING: Base de datos no encontrada en ${DB_PATH}"
    fi
}

# Función para actualizar estado del contenedor en DB
update_container_status_in_db() {
    local container_id=$1
    local status=$2
    
    if [ -f "${DB_PATH}" ]; then
        sqlite3 "${DB_PATH}" "UPDATE containers SET status='${status}' WHERE container_id='${container_id}';" 2>/dev/null
    fi
}

# Función para registrar contenedor eliminado en la base de datos
register_deleted_container() {
    local container_id=$1
    local deletion_reason=$2
    local timestamp=$(date +%s)000
    
    if [ -f "${DB_PATH}" ]; then
        # Obtener información del contenedor antes de eliminarlo
        local container_info=$(sqlite3 "${DB_PATH}" "SELECT container_name, image_name, ram_usage, cpu_usage, created_at FROM containers WHERE container_id='${container_id}';" 2>/dev/null)
        
        if [ -n "${container_info}" ]; then
            # Separar los valores (formato: name|image|ram|cpu|created)
            IFS='|' read -r name image ram cpu created <<< "${container_info}"
            
            # Insertar en tabla de eliminados
            sqlite3 "${DB_PATH}" "INSERT INTO deleted_containers (container_id, container_name, image_name, deletion_reason, ram_usage, cpu_usage, created_at, deleted_at) VALUES ('${container_id}', '${name}', '${image}', '${deletion_reason}', ${ram}, ${cpu}, ${created}, ${timestamp});" 2>/dev/null
            
            if [ $? -eq 0 ]; then
                log "DB: Eliminación de contenedor ${name} registrada (razón: ${deletion_reason})"
            fi
        fi
    fi
}

# Función para limpiar recursos de Docker después de eliminar contenedores
cleanup_docker_resources() {
    print_color "${YELLOW}" "🧹 Liberando recursos de Docker..."
    
    # Limpiar contenedores detenidos, redes no usadas, imágenes dangling y build cache
    local prune_output=$(docker system prune -f 2>&1)
    
    if [ $? -eq 0 ]; then
        log "CLEANUP: Docker system prune ejecutado exitosamente"
        # Extraer espacio liberado si está disponible
        local space_reclaimed=$(echo "${prune_output}" | grep -i "Total reclaimed space" || echo "Espacio liberado")
        if [ -n "${space_reclaimed}" ]; then
            print_color "${GREEN}" "  ✓ ${space_reclaimed}"
            log "CLEANUP: ${space_reclaimed}"
        fi
    else
        log "WARNING: Error ejecutando docker system prune"
    fi
}

# Función para imprimir con color
print_color() {
    local color=$1
    shift
    echo -e "${color}$@${NC}"
}

# Arrays de imágenes disponibles
HIGH_CONSUMPTION_IMAGES=(
    "memcached:alpine"
    "rabbitmq:3-management-alpine"
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
    # ACTUALIZADO: Incluye todas las imágenes posibles
    local result=$(docker ps -a 2>/dev/null | grep -E "mongo|nginx|busybox|postgres|redis|memcached|rabbitmq|httpd" | grep -v "grafana" | wc -l)
    echo "${result}"
}

# Función para contar contenedores de alto consumo
count_high_consumption() {
    # ACTUALIZADO: Agregamos memcached, rabbitmq y httpd al grep
    local result=$(docker ps -a 2>/dev/null | grep -E "mongo|postgres|redis|memcached|rabbitmq|httpd" | grep -v "grafana" | wc -l)
    echo "${result}"
}

# Función para contar contenedores de bajo consumo
count_low_consumption() {
    local result=$(docker ps -a 2>/dev/null | grep -E "nginx|busybox" | grep -v "grafana" | wc -l)
    echo "${result}"
}

# Función para verificar si una imagen es de alto consumo
is_high_consumption() {
    local image=$1
    for high_img in "${HIGH_CONSUMPTION_IMAGES[@]}"; do
        if [[ "${image}" == *"${high_img%%:*}"* ]]; then
            return 0
        fi
    done
    return 1
}

# Función para generar un contenedor aleatorio SIN verificar límites
generate_random_container() {
    local index=$1
    local selected_image=""
    local description=""
    
    # Seleccionar imagen aleatoria sin restricciones
    local random_index=$((RANDOM % ${#IMAGES[@]}))
    selected_image="${IMAGES[$random_index]}"
    
    # Determinar descripción
    local is_high=false
    for high_img in "${HIGH_CONSUMPTION_IMAGES[@]}"; do
        if [ "${selected_image}" == "${high_img}" ]; then
            is_high=true
            description="${HIGH_DESC}"
            break
        fi
    done
    
    if [ "${is_high}" == "false" ]; then
        description="${LOW_DESC}"
    fi
    
    # Generar nombre único para el contenedor
    local timestamp=$(date +%Y%m%d_%H%M%S)
    local random_suffix=$((RANDOM % 10000))
    local image_name=$(echo "${selected_image}" | tr '/:' '_' | cut -d'_' -f1-2)
    local container_name="${image_name}_${timestamp}_${random_suffix}"
    
    print_color "${BLUE}" "[$index/${CONTAINERS_TO_GENERATE}] Generando: ${container_name}"
    log "Generando contenedor ${index}: ${container_name} (${description} - ${selected_image})"
    
    # Ejecutar contenedor (configuración especial por imagen)
    # --log-opt max-size=1m limita los logs a 1MB para ahorrar espacio
    local docker_cmd="docker run -d --name ${container_name} --log-opt max-size=1m --log-opt max-file=1"
    
    case "${selected_image}" in
        elasticsearch:*)
            docker_cmd="${docker_cmd} -e discovery.type=single-node -e xpack.security.enabled=false ${selected_image}"
            ;;
        mongo:*)
            docker_cmd="${docker_cmd} -e MONGO_INITDB_ROOT_USERNAME=admin -e MONGO_INITDB_ROOT_PASSWORD=password ${selected_image}"
            ;;
        postgres:*)
            docker_cmd="${docker_cmd} -e POSTGRES_USER=admin -e POSTGRES_PASSWORD=password -e POSTGRES_DB=testdb ${selected_image}"
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
        # Obtener el ID del contenedor creado
        local created_container_id=$(docker ps -a --filter "name=${container_name}" --format "{{.ID}}" | head -n 1)
        
        print_color "${GREEN}" "  ✓ Contenedor creado exitosamente (ID: ${created_container_id})"
        log "SUCCESS: Contenedor ${container_name} creado (${selected_image})"
        
        # Registrar en la base de datos
        insert_container_to_db "${created_container_id}" "${container_name}" "${selected_image}" "running"
        
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
    print_color "${GREEN}" "  Generador con Límites por Categoría"
    if [ "${CONTINUOUS_MODE}" == "true" ]; then
        print_color "${GREEN}" "  MODO CONTINUO ACTIVADO"
    fi
    print_color "${GREEN}" "=========================================="
    echo
    
    log "=== Inicio de generación de contenedores ==="
    
    # Verificar Docker
    if ! command -v docker &> /dev/null; then
        print_color "${RED}" "Error: Docker no está instalado"
        log "ERROR: Docker no disponible"
        exit 1
    fi
    
    # Función para un ciclo de generación
    run_generation_cycle() {
        local cycle_number=$1
        
        if [ "${CONTINUOUS_MODE}" == "true" ]; then
            print_color "${MAGENTA}" "\n╔══════════════════════════════════════════╗"
            print_color "${MAGENTA}" "║  Ciclo #${cycle_number} - $(date '+%H:%M:%S')"
            print_color "${MAGENTA}" "╚══════════════════════════════════════════╝"
        fi
        
        # Contar contenedores actuales
        local current_count=$(count_containers)
        local high_count=$(count_high_consumption)
        local low_count=$(count_low_consumption)
        
        print_color "${YELLOW}" "Estado actual:"
        print_color "${BLUE}" "  Total: ${current_count} (máximo: ${MAX_CONTAINERS_TOTAL})"
        print_color "${BLUE}" "  Alto consumo: ${high_count} (mínimo: ${MIN_HIGH_CONSUMPTION}, máximo: ${MAX_HIGH_CONSUMPTION})"
        print_color "${BLUE}" "  Bajo consumo: ${low_count} (mínimo: ${MIN_LOW_CONSUMPTION}, máximo: ${MAX_LOW_CONSUMPTION})"
        
        log "Contenedores: Total=${current_count}, Alto=${high_count}, Bajo=${low_count}"
        
        # VERIFICAR LÍMITE MÁXIMO TOTAL ANTES DE GENERAR
        if [ ${current_count} -ge ${MAX_CONTAINERS_TOTAL} ]; then
            print_color "${RED}" "⚠️  LÍMITE MÁXIMO ALCANZADO (${current_count}/${MAX_CONTAINERS_TOTAL})"
            print_color "${YELLOW}" "No se generarán más contenedores para evitar sobrecarga del sistema"
            log "WARNING: Límite máximo de ${MAX_CONTAINERS_TOTAL} contenedores alcanzado, no se generan nuevos"
            
            # Aplicar limpieza por límites de categoría si es necesario
            local deleted_count=0
            
            # Verificar y limpiar alto consumo (respetando mínimo)
            if [ ${high_count} -gt ${MAX_HIGH_CONSUMPTION} ]; then
                local to_remove=$((high_count - MAX_HIGH_CONSUMPTION))
                print_color "${YELLOW}" "Limpiando ${to_remove} contenedores de alto consumo..."
                
                local containers_to_delete=$(docker ps -a --format "{{.ID}} {{.CreatedAt}} {{.Names}}" 2>/dev/null | \
                    grep -E "mongo|postgres|redis|memcached|rabbitmq|httpd" | \
                    grep -v "grafana" | \
                    sort -k2 | \
                    head -n ${to_remove} | \
                    awk '{print $1}')
                
                for container_id in ${containers_to_delete}; do
                    if [ -n "${container_id}" ]; then
                        # Verificar que no bajemos del mínimo
                        local current_high=$(count_high_consumption)
                        if [ ${current_high} -le ${MIN_HIGH_CONSUMPTION} ]; then
                            print_color "${RED}" "  ⚠️  No se puede eliminar: mínimo de ${MIN_HIGH_CONSUMPTION} contenedores de alto consumo alcanzado"
                            break
                        fi
                        register_deleted_container "${container_id}" "limite_maximo_sistema"
                        update_container_status_in_db "${container_id}" "removed"
                        docker rm -f ${container_id} > /dev/null 2>&1
                        print_color "${MAGENTA}" "  ✓ Contenedor ${container_id} eliminado"
                        deleted_count=$((deleted_count + 1))
                    fi
                done
            fi
            
            # Verificar y limpiar bajo consumo (respetando mínimo)
            if [ ${low_count} -gt ${MAX_LOW_CONSUMPTION} ]; then
                local to_remove=$((low_count - MAX_LOW_CONSUMPTION))
                print_color "${YELLOW}" "Limpiando ${to_remove} contenedores de bajo consumo..."
                
                local containers_to_delete=$(docker ps -a --format "{{.ID}} {{.CreatedAt}} {{.Names}}" 2>/dev/null | \
                    grep -E "nginx|busybox" | \
                    grep -v "grafana" | \
                    sort -k2 | \
                    head -n ${to_remove} | \
                    awk '{print $1}')
                
                for container_id in ${containers_to_delete}; do
                    if [ -n "${container_id}" ]; then
                        # Verificar que no bajemos del mínimo
                        local current_low=$(count_low_consumption)
                        if [ ${current_low} -le ${MIN_LOW_CONSUMPTION} ]; then
                            print_color "${RED}" "  ⚠️  No se puede eliminar: mínimo de ${MIN_LOW_CONSUMPTION} contenedores de bajo consumo alcanzado"
                            break
                        fi
                        register_deleted_container "${container_id}" "limite_maximo_sistema"
                        update_container_status_in_db "${container_id}" "removed"
                        docker rm -f ${container_id} > /dev/null 2>&1
                        print_color "${MAGENTA}" "  ✓ Contenedor ${container_id} eliminado"
                        deleted_count=$((deleted_count + 1))
                    fi
                done
            fi
            
            if [ ${deleted_count} -gt 0 ]; then
                log "CLEANUP: ${deleted_count} contenedores eliminados por límite máximo"
                cleanup_docker_resources
            fi
            
            return
        fi
        
        # SIEMPRE generar la cantidad configurada
        local to_generate=${CONTAINERS_TO_GENERATE}
        
        echo
        print_color "${YELLOW}" "Generando ${to_generate} contenedores nuevos aleatoriamente..."
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
        
        # Conteo después de generar
        local after_gen_count=$(count_containers)
        local after_gen_high=$(count_high_consumption)
        local after_gen_low=$(count_low_consumption)
        
        echo
        print_color "${GREEN}" "=========================================="
        print_color "${GREEN}" "  Resumen de Generación"
        print_color "${GREEN}" "=========================================="
        print_color "${GREEN}" "Contenedores creados: ${success_count}/${to_generate}"
        if [ ${fail_count} -gt 0 ]; then
            print_color "${RED}" "Contenedores fallidos: ${fail_count}"
        fi
        print_color "${BLUE}" "Total después de generar: ${after_gen_count}"
        print_color "${BLUE}" "Alto consumo: ${after_gen_high}/${MAX_HIGH_CONSUMPTION}"
        print_color "${BLUE}" "Bajo consumo: ${after_gen_low}/${MAX_LOW_CONSUMPTION}"
        
        # AHORA verificar y limpiar si se sobrepasaron los límites
        echo
        print_color "${YELLOW}" "Verificando límites después de generar..."
        
        local deleted_count=0
        
        # Verificar límite de alto consumo (respetando mínimo)
        if [ ${after_gen_high} -gt ${MAX_HIGH_CONSUMPTION} ]; then
            local to_remove=$((after_gen_high - MAX_HIGH_CONSUMPTION))
            print_color "${YELLOW}" "⚠️  Exceso de alto consumo: ${to_remove} contenedores a eliminar"
            
            # Obtener todos juntos y ordenar por fecha
            local containers_to_delete=$(docker ps -a --format "{{.ID}} {{.CreatedAt}} {{.Names}}" 2>/dev/null | \
                grep -E "mongo|postgres|redis|memcached|rabbitmq|httpd" | \
                grep -v "grafana" | \
                sort -k2 | \
                head -n ${to_remove} | \
                awk '{print $1}')
            
            # Eliminar contenedores
            for container_id in ${containers_to_delete}; do
                if [ -n "${container_id}" ]; then
                    # Verificar que no bajemos del mínimo
                    local current_high=$(count_high_consumption)
                    if [ ${current_high} -le ${MIN_HIGH_CONSUMPTION} ]; then
                        print_color "${RED}" "  ⚠️  No se puede eliminar más: mínimo de ${MIN_HIGH_CONSUMPTION} contenedores de alto consumo alcanzado"
                        break
                    fi
                    register_deleted_container "${container_id}" "exceso_limite_alto_consumo"
                    update_container_status_in_db "${container_id}" "removed"
                    docker rm -f ${container_id} > /dev/null 2>&1
                    print_color "${MAGENTA}" "  ✓ Contenedor alto consumo ${container_id} eliminado"
                    log "CLEANUP: Contenedor alto consumo ${container_id} eliminado por exceso"
                    deleted_count=$((deleted_count + 1))
                fi
            done
        fi
        
        # Verificar límite de bajo consumo (respetando mínimo)
        after_gen_low=$(count_low_consumption)
        if [ ${after_gen_low} -gt ${MAX_LOW_CONSUMPTION} ]; then
            local to_remove=$((after_gen_low - MAX_LOW_CONSUMPTION))
            print_color "${YELLOW}" "⚠️  Exceso de bajo consumo: ${to_remove} contenedores a eliminar"
            
            # Obtener todos los contenedores de bajo consumo y ordenar por fecha
            local containers_to_delete=$(docker ps -a --format "{{.ID}} {{.CreatedAt}} {{.Names}}" 2>/dev/null | \
                grep -E "nginx|busybox" | \
                grep -v "grafana" | \
                sort -k2 | \
                head -n ${to_remove} | \
                awk '{print $1}')
            
            # Eliminar contenedores
            for container_id in ${containers_to_delete}; do
                if [ -n "${container_id}" ]; then
                    # Verificar que no bajemos del mínimo
                    local current_low=$(count_low_consumption)
                    if [ ${current_low} -le ${MIN_LOW_CONSUMPTION} ]; then
                        print_color "${RED}" "  ⚠️  No se puede eliminar más: mínimo de ${MIN_LOW_CONSUMPTION} contenedores de bajo consumo alcanzado"
                        break
                    fi
                    register_deleted_container "${container_id}" "exceso_limite_bajo_consumo"
                    update_container_status_in_db "${container_id}" "removed"
                    docker rm -f ${container_id} > /dev/null 2>&1
                    print_color "${MAGENTA}" "  ✓ Contenedor bajo consumo ${container_id} eliminado"
                    log "CLEANUP: Contenedor bajo consumo ${container_id} eliminado por exceso"
                    deleted_count=$((deleted_count + 1))
                fi
            done
        fi
        
        # Conteo final después de limpieza
        local final_count=$(count_containers)
        local final_high=$(count_high_consumption)
        local final_low=$(count_low_consumption)
        
        echo
        print_color "${GREEN}" "=========================================="
        print_color "${GREEN}" "  Estado Final"
        print_color "${GREEN}" "=========================================="
        if [ ${deleted_count} -gt 0 ]; then
            print_color "${MAGENTA}" "Contenedores eliminados: ${deleted_count}"
            # Limpiar recursos de Docker después de eliminar contenedores
            cleanup_docker_resources
        fi
        print_color "${BLUE}" "Total final: ${final_count}"
        print_color "${BLUE}" "Alto consumo: ${final_high}/${MAX_HIGH_CONSUMPTION}"
        print_color "${BLUE}" "Bajo consumo: ${final_low}/${MAX_LOW_CONSUMPTION}"
        
        log "=== Fin ciclo ${cycle_number}: ${success_count} creados, ${deleted_count} eliminados ==="
        log "=== Estado final: Total=${final_count}, Alto=${final_high}, Bajo=${final_low} ==="
    }
    
    # Modo continuo o una sola ejecución
    if [ "${CONTINUOUS_MODE}" == "true" ]; then
        print_color "${GREEN}" "Iniciando generación continua (Ctrl+C para detener)..."
        print_color "${BLUE}" "Intervalo: ${GENERATION_INTERVAL} segundos"
        echo
        
        local cycle=1
        while true; do
            run_generation_cycle ${cycle}
            
            if [ ${cycle} -eq 1 ]; then
                echo
                print_color "${BLUE}" "Para ver los contenedores: docker ps"
                print_color "${BLUE}" "Para ver estadísticas: docker stats"
                print_color "${BLUE}" "Para detener: Ctrl+C"
            fi
            
            echo
            print_color "${YELLOW}" "⏳ Esperando ${GENERATION_INTERVAL} segundos hasta el próximo ciclo..."
            sleep ${GENERATION_INTERVAL}
            
            cycle=$((cycle + 1))
        done
    else
        run_generation_cycle 1
        
        echo
        print_color "${BLUE}" "Para ver los contenedores: docker ps"
        print_color "${BLUE}" "Para ver estadísticas: docker stats"
    fi
}

# Ejecutar función principal
main "$@"
