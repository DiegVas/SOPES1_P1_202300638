#!/bin/bash

###############################################################################
# Script de compilación del proyecto
# 
# Este script:
# 1. Compila los módulos del kernel (sysinfo y continfo)
# 2. Compila el proyecto de Go
###############################################################################

# Colores para output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Obtener directorio del script
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Función para imprimir con color
print_color() {
    local color=$1
    shift
    echo -e "${color}$@${NC}"
}

# Función para imprimir separador
print_separator() {
    print_color "${BLUE}" "=========================================="
}

# Verificar que estamos en el directorio correcto
if [ ! -f "${SCRIPT_DIR}/main.go" ]; then
    print_color "${RED}" "Error: No se encuentra main.go en el directorio actual"
    exit 1
fi

print_separator
print_color "${GREEN}" "  Compilación del Proyecto SOPES1"
print_separator
echo

# 0. Preparar headers del kernel si es necesario
print_color "${YELLOW}" "[0/3] Verificando headers del kernel..."
KERNEL_HEADERS="/usr/src/linux-headers-$(uname -r)"

if [ ! -f "${KERNEL_HEADERS}/include/generated/autoconf.h" ]; then
    print_color "${YELLOW}" "Preparando headers del kernel..."
    cd "${KERNEL_HEADERS}"
    sudo make scripts 2>/dev/null || print_color "${YELLOW}" "Advertencia: No se pudieron preparar scripts (puede ser normal)"
    cd "${SCRIPT_DIR}"
else
    print_color "${GREEN}" "✓ Headers del kernel OK"
fi

echo

# 1. Compilar módulo de métricas del sistema (sysinfo)
print_color "${YELLOW}" "[1/3] Compilando módulo del kernel: sysinfo..."
cd "${SCRIPT_DIR}/kernel_modules/metric_computer_module"

if [ ! -f "Makefile" ]; then
    print_color "${RED}" "Error: No se encuentra Makefile en metric_computer_module"
    exit 1
fi

make clean > /dev/null 2>&1
make

if [ $? -eq 0 ] && [ -f "computer_metric.ko" ]; then
    print_color "${GREEN}" "✓ Módulo sysinfo compilado exitosamente"
else
    print_color "${RED}" "✗ Error al compilar módulo sysinfo"
    exit 1
fi

echo

# 2. Compilar módulo de métricas de procesos (continfo)
print_color "${YELLOW}" "[2/3] Compilando módulo del kernel: continfo..."
cd "${SCRIPT_DIR}/kernel_modules/metric_process_module"

if [ ! -f "Makefile" ]; then
    print_color "${RED}" "Error: No se encuentra Makefile en metric_process_module"
    exit 1
fi

make clean > /dev/null 2>&1
make

if [ $? -eq 0 ] && [ -f "process_metric.ko" ]; then
    print_color "${GREEN}" "✓ Módulo continfo compilado exitosamente"
else
    print_color "${RED}" "✗ Error al compilar módulo continfo"
    exit 1
fi

echo

# 3. Compilar proyecto de Go
print_color "${YELLOW}" "[3/3] Compilando proyecto de Go..."
cd "${SCRIPT_DIR}"

go build -o main main.go

if [ $? -eq 0 ] && [ -f "main" ]; then
    print_color "${GREEN}" "✓ Proyecto Go compilado exitosamente"
    chmod +x main
else
    print_color "${RED}" "✗ Error al compilar proyecto Go"
    exit 1
fi

echo
print_separator
print_color "${GREEN}" "  Compilación Completada"
print_separator
echo

print_color "${BLUE}" "Ejecutables generados:"
print_color "${BLUE}" "  • ${SCRIPT_DIR}/sopes1_monitor (Programa principal)"
print_color "${BLUE}" "  • kernel_modules/metric_computer_module/computer_metric.ko"
print_color "${BLUE}" "  • kernel_modules/metric_process_module/process_metric.ko"
echo

print_color "${YELLOW}" "Para ejecutar el programa:"
print_color "${YELLOW}" "  sudo ./sopes1_monitor"
echo

print_color "${YELLOW}" "Nota: Se requieren permisos de root para cargar los módulos del kernel"
