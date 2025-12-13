package utils

import (
	"database/sql"
	"log"
	"os/exec"
	"strings"
	"time"
)

// SyncDockerContainers sincroniza los contenedores de Docker con la base de datos
func SyncDockerContainers(db *sql.DB) error {
	// Obtener todos los contenedores corriendo
	cmd := exec.Command("docker", "ps", "--format", "{{.ID}}|{{.Names}}|{{.Image}}|{{.Status}}")
	output, err := cmd.Output()
	if err != nil {
		return err
	}

	lines := strings.Split(string(output), "\n")
	timestamp := time.Now().UnixMilli()
	syncedCount := 0

	// Crear mapa de contenedores activos
	activeContainers := make(map[string]bool)

	for _, line := range lines {
		if line == "" {
			continue
		}

		parts := strings.Split(line, "|")
		if len(parts) < 4 {
			continue
		}

		containerID := parts[0]
		containerName := parts[1]
		imageName := parts[2]
		status := "running"

		// Marcar como activo
		activeContainers[containerID] = true

		// Insertar o actualizar en la base de datos
		_, err := db.Exec(`
			INSERT INTO containers (container_id, container_name, image_name, status, created_at, updated_at, ram_usage, cpu_usage)
			VALUES (?, ?, ?, ?, ?, ?, 0, 0)
			ON CONFLICT(container_id) DO UPDATE SET
				status = excluded.status,
				updated_at = excluded.updated_at
		`, containerID, containerName, imageName, status, timestamp, timestamp)

		if err != nil {
			log.Printf("Error sincronizando contenedor %s: %v", containerName, err)
			continue
		}
		syncedCount++
	}

	// Guardar contenedores eliminados antes de marcarlos como stopped
	// Buscar contenedores que están en la BD pero ya no en Docker
	rows, err := db.Query(`
		SELECT container_id, container_name, image_name, ram_usage, cpu_usage, created_at
		FROM containers 
		WHERE status IN ('running', 'stopped')
	`)

	if err != nil {
		log.Printf("Error consultando contenedores para detectar eliminados: %v", err)
	} else {
		deletedCount := 0
		for rows.Next() {
			var containerID, containerName, imageName string
			var ramUsage, cpuUsage float64
			var createdAt int64

			err := rows.Scan(&containerID, &containerName, &imageName, &ramUsage, &cpuUsage, &createdAt)
			if err != nil {
				log.Printf("Error escaneando contenedor: %v", err)
				continue
			}

			// Si el contenedor está en activeContainers, está corriendo ahora mismo
			if activeContainers[containerID] {
				continue
			}

			// Excluir contenedores del sistema
			if isSystemContainer(containerName, imageName) {
				continue
			}

			// Verificar si el contenedor realmente fue eliminado de Docker
			checkCmd := exec.Command("docker", "ps", "-a", "--filter", "id="+containerID, "--format", "{{.ID}}")
			checkOutput, _ := checkCmd.Output()
			containerStillExists := strings.TrimSpace(string(checkOutput)) != ""

			// Solo registrar como eliminado si ya no existe en Docker y aún no está en deleted_containers
			if !containerStillExists {
				// Verificar que no esté ya registrado
				var exists int
				err := db.QueryRow(`SELECT COUNT(*) FROM deleted_containers WHERE container_id = ?`, containerID).Scan(&exists)
				if err == nil && exists == 0 {
					// Insertar en tabla de contenedores eliminados
					_, err := db.Exec(`
						INSERT INTO deleted_containers (container_id, container_name, image_name, deletion_reason, ram_usage, cpu_usage, created_at, deleted_at)
						VALUES (?, ?, ?, ?, ?, ?, ?, ?)
					`, containerID, containerName, imageName, "Container removed from system", ramUsage, cpuUsage, createdAt, timestamp)

					if err != nil {
						log.Printf("Error guardando contenedor eliminado %s: %v", containerName, err)
					} else {
						deletedCount++
						log.Printf("✓ Contenedor eliminado registrado: %s (%s)", containerName, containerID[:12])

						// Eliminar de la tabla containers
						db.Exec(`DELETE FROM containers WHERE container_id = ?`, containerID)
					}
				}
			}
		}
		rows.Close()

		if deletedCount > 0 {
			log.Printf("✅ Registrados %d contenedores eliminados en deleted_containers", deletedCount)
		}
	}

	// Marcar como stopped los contenedores que ya no existen
	if len(activeContainers) > 0 {
		// Construir la consulta con placeholders para cada ID
		placeholders := make([]string, 0, len(activeContainers))
		args := make([]interface{}, 0, len(activeContainers)+1)
		args = append(args, timestamp)

		for id := range activeContainers {
			placeholders = append(placeholders, "?")
			args = append(args, id)
		}

		query := `UPDATE containers 
			SET status = 'stopped', updated_at = ?
			WHERE status = 'running' 
			AND container_id NOT IN (` + strings.Join(placeholders, ",") + `)`

		result, err := db.Exec(query, args...)
		if err != nil {
			log.Printf("Advertencia al actualizar contenedores detenidos: %v", err)
		} else {
			stoppedCount, _ := result.RowsAffected()
			if stoppedCount > 0 {
				log.Printf("Marcados %d contenedores como stopped", stoppedCount)
			}
		}
	} else {
		// Si no hay contenedores activos, marcar todos como stopped
		result, err := db.Exec(`UPDATE containers SET status = 'stopped', updated_at = ? WHERE status = 'running'`, timestamp)
		if err != nil {
			log.Printf("Advertencia al actualizar contenedores detenidos: %v", err)
		} else {
			stoppedCount, _ := result.RowsAffected()
			if stoppedCount > 0 {
				log.Printf("Marcados %d contenedores como stopped", stoppedCount)
			}
		}
	}

	log.Printf("Sincronizados %d contenedores en la base de datos", syncedCount)

	// Registrar contenedores stopped que ya no existen en Docker
	go RegisterDeletedStoppedContainers(db)

	return nil
}

// RegisterDeletedStoppedContainers registra los contenedores stopped que ya no existen en Docker
func RegisterDeletedStoppedContainers(db *sql.DB) {
	timestamp := time.Now().UnixMilli()

	// Obtener todos los contenedores stopped de la BD
	rows, err := db.Query(`
		SELECT container_id, container_name, image_name, ram_usage, cpu_usage, created_at
		FROM containers 
		WHERE status = 'stopped'
	`)

	if err != nil {
		log.Printf("Error consultando contenedores stopped: %v", err)
		return
	}
	defer rows.Close()

	registeredCount := 0
	for rows.Next() {
		var containerID, containerName, imageName string
		var ramUsage, cpuUsage float64
		var createdAt int64

		err := rows.Scan(&containerID, &containerName, &imageName, &ramUsage, &cpuUsage, &createdAt)
		if err != nil {
			continue
		}

		// Excluir contenedores del sistema
		if isSystemContainer(containerName, imageName) {
			continue
		}

		// Verificar si el contenedor existe en Docker
		checkCmd := exec.Command("docker", "ps", "-a", "--filter", "id="+containerID, "--format", "{{.ID}}")
		checkOutput, _ := checkCmd.Output()
		containerExists := strings.TrimSpace(string(checkOutput)) != ""

		// Si no existe en Docker, verificar que no esté ya registrado como eliminado
		if !containerExists {
			var existsInDeleted int
			err := db.QueryRow(`SELECT COUNT(*) FROM deleted_containers WHERE container_id = ?`, containerID).Scan(&existsInDeleted)

			if err == nil && existsInDeleted == 0 {
				// Registrar en deleted_containers
				_, err := db.Exec(`
					INSERT INTO deleted_containers (container_id, container_name, image_name, deletion_reason, ram_usage, cpu_usage, created_at, deleted_at)
					VALUES (?, ?, ?, ?, ?, ?, ?, ?)
				`, containerID, containerName, imageName, "Container physically removed", ramUsage, cpuUsage, createdAt, timestamp)

				if err == nil {
					registeredCount++
					log.Printf("✓ Contenedor stopped eliminado registrado: %s (%s)", containerName, containerID[:12])

					// Eliminar de la tabla containers
					db.Exec(`DELETE FROM containers WHERE container_id = ?`, containerID)
				}
			}
		}
	}

	if registeredCount > 0 {
		log.Printf("Registrados %d contenedores stopped eliminados", registeredCount)
	}
}

// isSystemContainer verifica si un contenedor es del sistema (Grafana, Prometheus, etc.)
func isSystemContainer(containerName, imageName string) bool {
	// Nombres de contenedores del sistema a excluir
	systemNames := []string{
		"grafana",
		"prometheus",
		"loki",
		"influxdb",
		"telegraf",
		"cadvisor",
	}

	// Imágenes del sistema a excluir
	systemImages := []string{
		"grafana/grafana",
		"prom/prometheus",
		"grafana/loki",
		"influxdb",
		"telegraf",
		"gcr.io/cadvisor",
	}

	containerNameLower := strings.ToLower(containerName)
	imageNameLower := strings.ToLower(imageName)

	// Verificar nombres
	for _, sysName := range systemNames {
		if strings.Contains(containerNameLower, sysName) {
			return true
		}
	}

	// Verificar imágenes
	for _, sysImage := range systemImages {
		if strings.Contains(imageNameLower, sysImage) {
			return true
		}
	}

	return false
}

// getKeys obtiene las claves de un mapa
func getKeys(m map[string]bool) []string {
	keys := make([]string, 0, len(m))
	for k := range m {
		keys = append(keys, k)
	}
	return keys
}
