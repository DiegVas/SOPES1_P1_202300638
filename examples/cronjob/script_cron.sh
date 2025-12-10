#!/bin/bash

# Script para leer métricas del sistema
echo "=== Métricas del Sistema - $(date) ==="

# Leer métricas del sistema
if [ -f /proc/sysinfo ]; then
    echo "--- Métricas de Sistema ---"
    cat /proc/sysinfo
fi

echo "=== Fin de Métricas ==="
