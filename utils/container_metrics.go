package utils

import (
	"database/sql"
	"fmt"
	"log"
	"os/exec"
	"strconv"
	"strings"
	"time"
)

// ContainerMetrics almacena las métricas de un contenedor
type ContainerMetrics struct {
	ContainerID string
	RAMUsage    float64
	CPUUsage    float64
}

// IsContainerRunning verifica si un contenedor está en ejecución
func IsContainerRunning(containerID string) bool {
	cmd := exec.Command("docker", "inspect", "-f", "{{.State.Running}}", containerID)
	output, err := cmd.Output()
	if err != nil {
		return false
	}
	return strings.TrimSpace(string(output)) == "true"
}

// GetContainerPIDs obtiene los PIDs de un contenedor Docker
func GetContainerPIDs(containerID string) ([]int, error) {
	// Primero verificar si el contenedor está corriendo
	if !IsContainerRunning(containerID) {
		return []int{}, nil // Retornar lista vacía sin error
	}

	cmd := exec.Command("docker", "top", containerID, "-eo", "pid")
	output, err := cmd.Output()
	if err != nil {
		// Si falla docker top, retornar lista vacía sin error (contenedor puede haber terminado)
		return []int{}, nil
	}

	lines := strings.Split(string(output), "\n")
	var pids []int

	// Saltar la primera línea (header)
	for i, line := range lines {
		if i == 0 || line == "" {
			continue
		}

		fields := strings.Fields(line)
		if len(fields) > 0 {
			pid, err := strconv.Atoi(strings.TrimSpace(fields[0]))
			if err == nil {
				pids = append(pids, pid)
			}
		}
	}

	return pids, nil
}

// CalculateContainerMetrics calcula las métricas de un contenedor usando datos del módulo del kernel
func CalculateContainerMetrics(containerID string, processData map[string]interface{}) (*ContainerMetrics, error) {
	// Obtener PIDs del contenedor
	pids, err := GetContainerPIDs(containerID)
	if err != nil {
		return nil, err
	}

	if len(pids) == 0 {
		return &ContainerMetrics{
			ContainerID: containerID,
			RAMUsage:    0,
			CPUUsage:    0,
		}, nil
	}

	// Crear un mapa de PIDs para búsqueda rápida
	pidMap := make(map[int]bool)
	for _, pid := range pids {
		pidMap[pid] = true
	}

	// Extraer los procesos del JSON
	processes, ok := processData["Processes"].([]interface{})
	if !ok {
		return nil, fmt.Errorf("no se pudieron extraer los procesos")
	}

	var totalRAM float64
	var totalCPU float64

	// Sumar las métricas de los procesos que pertenecen al contenedor
	for _, proc := range processes {
		p, ok := proc.(map[string]interface{})
		if !ok {
			continue
		}

		pid := int(p["PID"].(float64))
		if pidMap[pid] {
			// Sumar RSS (memoria)
			if rss, ok := p["rss"].(float64); ok {
				totalRAM += rss
			}

			// Sumar CPU
			if cpuUsage, ok := p["CPU_Usage"].(float64); ok {
				totalCPU += cpuUsage
			}
		}
	}

	return &ContainerMetrics{
		ContainerID: containerID,
		RAMUsage:    totalRAM,
		CPUUsage:    totalCPU,
	}, nil
}

// GetActiveContainers obtiene la lista de contenedores activos desde la base de datos
func GetActiveContainers(db *sql.DB) ([]string, error) {
	rows, err := db.Query("SELECT container_id FROM containers WHERE status = 'running'")
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	var containerIDs []string
	for rows.Next() {
		var containerID string
		if err := rows.Scan(&containerID); err != nil {
			log.Printf("Error escaneando container_id: %v", err)
			continue
		}
		containerIDs = append(containerIDs, containerID)
	}

	return containerIDs, nil
}

// UpdateContainerMetrics actualiza las métricas de un contenedor en la base de datos
func UpdateContainerMetrics(db *sql.DB, metrics *ContainerMetrics) error {
	timestamp := time.Now().UnixMilli()

	_, err := db.Exec(`UPDATE containers 
		SET ram_usage = ?, cpu_usage = ?, updated_at = ? 
		WHERE container_id = ?`,
		metrics.RAMUsage, metrics.CPUUsage, timestamp, metrics.ContainerID)

	if err != nil {
		return fmt.Errorf("error actualizando métricas del contenedor %s: %v", metrics.ContainerID, err)
	}

	return nil
}

// UpdateAllContainerMetrics actualiza las métricas de todos los contenedores activos
func UpdateAllContainerMetrics(db *sql.DB, processData map[string]interface{}) error {
	// Obtener contenedores activos
	containerIDs, err := GetActiveContainers(db)
	if err != nil {
		return fmt.Errorf("error obteniendo contenedores activos: %v", err)
	}

	if len(containerIDs) == 0 {
		log.Println("No hay contenedores activos para actualizar")
		return nil
	}

	// Calcular y actualizar métricas para cada contenedor
	successCount := 0
	for _, containerID := range containerIDs {
		// Verificar si el contenedor sigue corriendo
		if !IsContainerRunning(containerID) {
			// Actualizar estado en la base de datos
			_, err := db.Exec("UPDATE containers SET status = 'stopped' WHERE container_id = ?", containerID)
			if err != nil {
				log.Printf("Error actualizando estado del contenedor %s: %v", containerID, err)
			}
			continue
		}

		metrics, err := CalculateContainerMetrics(containerID, processData)
		if err != nil {
			log.Printf("Error calculando métricas del contenedor %s: %v", containerID, err)
			continue
		}

		err = UpdateContainerMetrics(db, metrics)
		if err != nil {
			log.Printf("Error actualizando métricas: %v", err)
			continue
		}

		log.Printf("Contenedor %s - RAM: %.2f KB, CPU: %.2f%%",
			containerID[:12], metrics.RAMUsage, metrics.CPUUsage)
		successCount++
	}

	if successCount > 0 {
		log.Printf("Actualizadas métricas de %d/%d contenedores", successCount, len(containerIDs))
	}

	return nil
}
