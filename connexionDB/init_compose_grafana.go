package connexionDB

import (
	"fmt"
	"log"
	"os/exec"
	"path/filepath"
)

func Init_compose_grafana(exePath string) error {

	exeDir := filepath.Dir(exePath)
	composeFilePath := filepath.Join(exeDir, "connexionDB", "docker-compose.yml")

	log.Println("Buscando docker-compose en:", composeFilePath)

	// Primero intentar detener y eliminar contenedores existentes
	log.Println("Deteniendo contenedores previos...")
	downCmd := exec.Command("docker", "compose", "-f", composeFilePath, "down")
	downCmd.Run() // Ignorar errores si no hay contenedores

	//? Ejecutar docker compose up -d
	cmd := exec.Command("docker", "compose", "-f", composeFilePath, "up", "-d")
	output, err := cmd.CombinedOutput()
	if err != nil {
		log.Fatalf("Error al ejecutar el docker compose: %v\nOutput: %s", err, output)
		return err
	}

	fmt.Printf("Docker Compose Up exitoso:\n%s\n", output)
	return nil
}
