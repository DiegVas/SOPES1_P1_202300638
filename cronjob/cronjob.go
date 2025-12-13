package cronjob

import (
	"fmt"
	"log"
	"os"
	"os/exec"
	"path/filepath"
)

// SetupBasicCronjob configura el cronjob básico usando script_cron.sh
func SetupBasicCronjob() error {
	// Obtener ruta absoluta del script
	absPath, err := filepath.Abs("./script_cron.sh")
	if err != nil {
		return fmt.Errorf("error obteniendo ruta absoluta: %v", err)
	}
	scriptPath := absPath

	// 1. Hacer el script ejecutable
	if err := hacerEjecutableBasic(scriptPath); err != nil {
		return err
	}

	// 2. Agregar cronjob que se ejecute cada minuto
	if err := agregarCronJobBasic(scriptPath); err != nil {
		return err
	}

	// 3. Verificar que se agregó correctamente
	verificarCronJobs()

	log.Println("Cronjob configurado exitosamente!")
	return nil
}

// hacerEjecutableBasic cambia los permisos del archivo para que sea ejecutable
func hacerEjecutableBasic(ruta string) error {
	err := os.Chmod(ruta, 0755)
	if err != nil {
		return fmt.Errorf("error haciendo ejecutable el script: %v", err)
	}

	log.Printf("Script %s ahora es ejecutable", ruta)
	return nil
}

// agregarCronJobBasic agrega una nueva entrada a crontab
func agregarCronJobBasic(rutaScript string) error {
	expresionCron := "* * * * *"
	comandoCron := fmt.Sprintf("%s %s >> %s.log 2>&1", expresionCron, rutaScript, rutaScript)

	cmd := exec.Command("bash", "-c",
		fmt.Sprintf("(crontab -l 2>/dev/null; echo \"%s\") | crontab -", comandoCron))

	output, err := cmd.CombinedOutput()
	if err != nil {
		return fmt.Errorf("error agregando cronjob: %v\nOutput: %s", err, string(output))
	}

	log.Printf("Cronjob agregado: %s", comandoCron)
	return nil
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
