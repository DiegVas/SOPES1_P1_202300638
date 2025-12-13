package connexionDB

import (
	"log"
	"os"
	"os/exec"
	"path/filepath"
	"strings"
	"time"
)

func Init_compose_grafana(exePath string) error {

	exeDir := filepath.Dir(exePath)
	composeFilePath := filepath.Join(exeDir, "connexionDB", "docker-compose.yml")

	log.Println("Buscando docker-compose en:", composeFilePath)

	// Verificar que el archivo existe
	if _, err := os.Stat(composeFilePath); os.IsNotExist(err) {
		log.Printf("❌ ERROR: docker-compose.yml NO encontrado en %s", composeFilePath)
		log.Println("Continuando sin Grafana...")
		return nil
	}
	log.Println("✓ Archivo docker-compose.yml encontrado")

	// IMPORTANTE: Verificar que containers.db exista ANTES de iniciar el contenedor
	dbPath := filepath.Join(exeDir, "containers.db")
	log.Println("Verificando existencia de base de datos:", dbPath)

	if _, err := os.Stat(dbPath); os.IsNotExist(err) {
		log.Println("⚠️  ADVERTENCIA: containers.db no existe todavía")
		log.Println("La base de datos debe ser creada antes de iniciar Grafana")
		log.Println("Continuando sin Grafana (se iniciará en la siguiente ejecución)...")
		return nil
	}

	// Verificar que no sea un directorio
	if info, err := os.Stat(dbPath); err == nil && info.IsDir() {
		log.Println("❌ ERROR: containers.db es un directorio, debe ser un archivo")
		log.Println("Elimínalo manualmente: rm -rf", dbPath)
		return nil
	}

	// Verificar permisos del archivo
	if info, err := os.Stat(dbPath); err == nil {
		log.Printf("✓ Base de datos encontrada con permisos: %v", info.Mode().Perm())

		// Verificar también archivos WAL si existen
		walFiles := []string{dbPath + "-wal", dbPath + "-shm"}
		for _, walFile := range walFiles {
			if walInfo, err := os.Stat(walFile); err == nil {
				log.Printf("  • %s: %v", filepath.Base(walFile), walInfo.Mode().Perm())
			}
		}
	}

	log.Println("✓ Base de datos verificada:", dbPath)

	// Verificar si el contenedor ya existe
	checkCmd := exec.Command("docker", "ps", "-a", "--filter", "name=grafana-sqlite", "--format", "{{.Names}}")
	checkOutput, _ := checkCmd.Output()
	containerExists := strings.TrimSpace(string(checkOutput)) != ""

	// Cambiar al directorio del docker-compose
	originalDir, err := os.Getwd()
	if err != nil {
		log.Printf("⚠️  Error obteniendo directorio actual: %v", err)
		return nil
	}

	composeDir := filepath.Dir(composeFilePath)
	log.Println("📂 Cambiando a directorio:", composeDir)
	if err := os.Chdir(composeDir); err != nil {
		log.Printf("⚠️  Error cambiando de directorio: %v", err)
		return nil
	}
	defer os.Chdir(originalDir)

	// Solo hacer build si el contenedor no existe o está stopped
	var cmd *exec.Cmd
	if containerExists {
		// Verificar si está corriendo
		runningCmd := exec.Command("docker", "ps", "--filter", "name=grafana-sqlite", "--format", "{{.Names}}")
		runningOutput, _ := runningCmd.Output()
		isRunning := strings.TrimSpace(string(runningOutput)) != ""

		if isRunning {
			log.Println("✅ Grafana ya está corriendo, omitiendo inicialización")
			return nil
		}

		log.Println("🚀 Ejecutando: docker compose up -d (sin build)")
		cmd = exec.Command("docker", "compose", "up", "-d")
	} else {
		log.Println("🚀 Ejecutando: docker compose up -d --build (primera vez)")
		cmd = exec.Command("docker", "compose", "up", "-d", "--build")
	}

	// Redirigir stdout y stderr para ver el progreso
	cmd.Stdout = os.Stdout
	cmd.Stderr = os.Stderr

	err = cmd.Run()
	if err != nil {
		log.Printf("⚠️  Error al ejecutar docker compose: %v", err)
		log.Println("Continuando sin Grafana...")
		return nil
	}

	log.Println("✅ Docker Compose iniciado correctamente")

	// Esperar a que Grafana esté completamente listo
	log.Println("⏳ Esperando a que Grafana esté listo...")
	for i := 0; i < 30; i++ {
		healthCmd := exec.Command("docker", "inspect", "--format", "{{.State.Health.Status}}", "grafana-sqlite")
		healthOutput, _ := healthCmd.Output()
		health := strings.TrimSpace(string(healthOutput))

		// Si no tiene healthcheck, verificar que esté running
		if health == "" || health == "<no value>" {
			statusCmd := exec.Command("docker", "inspect", "--format", "{{.State.Status}}", "grafana-sqlite")
			statusOutput, _ := statusCmd.Output()
			status := strings.TrimSpace(string(statusOutput))

			if status == "running" {
				log.Println("✅ Grafana está corriendo")
				time.Sleep(2 * time.Second) // Dar tiempo adicional para que inicie completamente
				return nil
			}
		} else if health == "healthy" {
			log.Println("✅ Grafana está healthy y listo")
			return nil
		}

		time.Sleep(1 * time.Second)
	}

	log.Println("⚠️  Grafana tardó en estar listo, pero continuando...")
	return nil
}
