package main

import (
	"fmt"
	"log"
	"os"
	"os/exec"
	"path/filepath"
)

func main() {
	// Obtener ruta absoluta del script CON LÍMITES
	absPath, err := filepath.Abs("../docker_images/generate_containers_limited.sh")
	if err != nil {
		log.Fatalf("Error obteniendo ruta absoluta: %v", err)
	}
	scriptPath := absPath

	// 1. Hacer el script ejecutable
	hacerEjecutable(scriptPath)

	// 2. Agregar cronjob que se ejecute cada minuto
	agregarCronJob(scriptPath)

	// 3. Verificar que se agregó correctamente
	verificarCronJobs()

	log.Println("Cronjob para generación de contenedores Docker configurado exitosamente!")
}

// hacerEjecutable cambia los permisos del archivo para que sea ejecutable
func hacerEjecutable(ruta string) {
	err := os.Chmod(ruta, 0755)
	if err != nil {
		log.Fatalf("Error haciendo ejecutable el script: %v", err)
	}

	log.Printf("Script %s ahora es ejecutable", ruta)
}

// agregarCronJob agrega una nueva entrada a crontab para generar contenedores Docker
func agregarCronJob(rutaScript string) {
	expresionCron := "* * * * *"
	logPath := filepath.Dir(rutaScript) + "/cronjob_docker.log"
	comandoCron := fmt.Sprintf("%s %s >> %s 2>&1", expresionCron, rutaScript, logPath)

	cmd := exec.Command("bash", "-c",
		fmt.Sprintf("(crontab -l 2>/dev/null | grep -v '%s'; echo \"%s\") | crontab -",
			rutaScript, comandoCron))

	output, err := cmd.CombinedOutput()
	if err != nil {
		log.Fatalf("Error agregando cronjob: %v\nOutput: %s", err, string(output))
	}

	log.Printf("Cronjob agregado: %s", comandoCron)
}

// verificarCronJobs lista todos los cronjobs configurados
func verificarCronJobs() {
	cmd := exec.Command("crontab", "-l")
	output, err := cmd.CombinedOutput()

	if err != nil {
		log.Printf("No se pudieron listar cronjobs (puede estar vacío): %v", err)
	} else {
		log.Printf("=== Cronjobs Actuales ===\n%s=== Fin de Cronjobs ===", string(output))
	}
}
