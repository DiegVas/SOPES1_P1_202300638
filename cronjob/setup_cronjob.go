package cronjob

import (
	"fmt"
	"log"
	"os"
	"os/exec"
	"path/filepath"
)

// SetupDockerCronjob configura el cronjob para generar contenedores Docker
func SetupDockerCronjob(exePath string) error {
	exeDir := filepath.Dir(exePath)

	// Ruta al script de generación de contenedores
	scriptPath := filepath.Join(exeDir, "docker_images", "generate_containers_limited.sh")

	// Verificar que el script existe
	if _, err := os.Stat(scriptPath); os.IsNotExist(err) {
		return fmt.Errorf("script no encontrado: %s", scriptPath)
	}

	// 1. Hacer el script ejecutable
	if err := hacerEjecutable(scriptPath); err != nil {
		return fmt.Errorf("error haciendo ejecutable el script: %v", err)
	}

	// 2. Agregar cronjob
	if err := agregarCronJob(scriptPath); err != nil {
		return fmt.Errorf("error agregando cronjob: %v", err)
	}

	log.Println("Cronjob para generación de contenedores Docker configurado exitosamente!")
	return nil
}

// hacerEjecutable cambia los permisos del archivo para que sea ejecutable
func hacerEjecutable(ruta string) error {
	err := os.Chmod(ruta, 0755)
	if err != nil {
		return err
	}
	log.Printf("Script %s ahora es ejecutable", ruta)
	return nil
}

// agregarCronJob agrega una nueva entrada a crontab para generar contenedores Docker
func agregarCronJob(rutaScript string) error {
	expresionCron := "* * * * *"
	logPath := filepath.Dir(rutaScript) + "/cronjob_docker.log"
	comandoCron := fmt.Sprintf("%s %s >> %s 2>&1", expresionCron, rutaScript, logPath)

	cmd := exec.Command("bash", "-c",
		fmt.Sprintf("(crontab -l 2>/dev/null | grep -v '%s'; echo \"%s\") | crontab -",
			rutaScript, comandoCron))

	output, err := cmd.CombinedOutput()
	if err != nil {
		return fmt.Errorf("error ejecutando comando: %v\nOutput: %s", err, string(output))
	}

	log.Printf("Cronjob agregado: %s", comandoCron)
	return nil
}

// RemoveCronjob elimina el cronjob configurado
func RemoveCronjob(exePath string) error {
	exeDir := filepath.Dir(exePath)
	scriptPath := filepath.Join(exeDir, "docker_images", "generate_containers_limited.sh")

	cmd := exec.Command("bash", "-c",
		fmt.Sprintf("crontab -l 2>/dev/null | grep -v '%s' | crontab -", scriptPath))

	output, err := cmd.CombinedOutput()
	if err != nil {
		return fmt.Errorf("error removiendo cronjob: %v\nOutput: %s", err, string(output))
	}

	log.Println("Cronjob removido exitosamente")
	return nil
}
