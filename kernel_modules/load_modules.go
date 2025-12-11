package kernelmodules

import (
	"log"
	"os"
	"os/exec"
	"path/filepath"
	"time"
)

func LoadModules() {

	//* Rutas de los módulos del kernel

	// Obtener directorio de trabajo actual
	workDir, err := os.Getwd()
	if err != nil {
		log.Fatal("Error obteniendo directorio actual:", err)
	}

	//? Módulo de métrica de proceso
	modulePath := filepath.Join(workDir, "kernel_modules", "metric_process_module", "process_metric.ko")

	//? Módulo de métrica de computadora
	computerModulePath := filepath.Join(workDir, "kernel_modules", "metric_computer_module", "computer_metric.ko")

	log.Println("Cargando módulo del kernel de metrica de proceso desde:", modulePath)

	log.Println("Cargando módulo del kernel de metrica de computadora desde:", computerModulePath)

	processModuleLoaded := false
	computerModuleLoaded := false

	// Primero verificar si el módulo de metrica de proceso ya está cargado Y el archivo existe
	checkCmd := exec.Command("lsmod")
	checkOutput, _ := checkCmd.Output()
	if string(checkOutput) != "" && len(string(checkOutput)) > 0 {
		if exec.Command("sh", "-c", "lsmod | grep -q process_metric").Run() == nil {
			// Verificar si el archivo /proc existe
			if _, err := os.Stat("/proc/continfo_so1_202300638"); err == nil {
				log.Println("El módulo process_metric ya está cargado")
				processModuleLoaded = true
			} else {
				log.Println("El módulo process_metric está cargado pero el archivo /proc no existe, recargando...")
				exec.Command("sudo", "rmmod", "process_metric").Run()
			}
		}
	}

	// Verificar si el módulo de metrica de computadora ya está cargado Y el archivo existe
	if string(checkOutput) != "" && len(string(checkOutput)) > 0 {
		if exec.Command("sh", "-c", "lsmod | grep -q computer_metric").Run() == nil {
			// Verificar si el archivo /proc existe
			if _, err := os.Stat("/proc/sysinfo_so1_202300638"); err == nil {
				log.Println("El módulo computer_metric ya está cargado")
				computerModuleLoaded = true
			} else {
				log.Println("El módulo computer_metric está cargado pero el archivo /proc no existe, recargando...")
				exec.Command("sudo", "rmmod", "computer_metric").Run()
			}
		}
	}

	if !processModuleLoaded {
		// Cargar el módulo de metrica de proceso con insmod
		cmd := exec.Command("sudo", "insmod", modulePath)
		output, err := cmd.CombinedOutput()
		if err != nil {
			log.Fatalf("Error al cargar el módulo del kernel de metrica de proceso: %v\nOutput: %s", err, output)
		}
		log.Println("Módulo del kernel de metrica de proceso cargado exitosamente")

		// Verificar que el archivo /proc/sysinfo existe
		time.Sleep(1 * time.Second) // Dar tiempo para que se cree el archivo
		if _, err := os.Stat("/proc/sysinfo_so1_202300638"); os.IsNotExist(err) {
			log.Fatal("Error: /proc/sysinfo_so1_202300638 no fue creado después de cargar el módulo")
		}
		log.Println("Archivo /proc/sysinfo_so1_202300638 verificado correctamente")
	}

	if !computerModuleLoaded {
		// Cargar el módulo de metrica de computadora con insmod
		cmd := exec.Command("sudo", "insmod", computerModulePath)
		output, err := cmd.CombinedOutput()
		if err != nil {
			log.Fatalf("Error al cargar el módulo del kernel de metrica de computadora: %v\nOutput: %s", err, output)
		}
		log.Println("Módulo del kernel de metrica de computadora cargado exitosamente")

		// Verificar que el archivo /proc/computer_sysinfo existe
		time.Sleep(1 * time.Second) // Dar tiempo para que se cree el archivo
		if _, err := os.Stat("/proc/continfo_so1_202300638"); os.IsNotExist(err) {
			log.Fatal("Error: /proc/continfo_so1_202300638 no fue creado después de cargar el módulo")
		}
		log.Println("Archivo /proc/continfo_so1_202300638 verificado correctamente")
	}

}
