package main

import (
	"fmt"
	"log"
	"math/rand"
	"os"
	"os/signal"
	"syscall"
	"time"

	"main/connexionDB"
	kernelmodules "main/kernel_modules"
	"main/utils"
)

func main() {
	// Inicializar aleatoriedad
	rand.Seed(time.Now().UnixNano())

	//? Obtener directorio del ejecutable
	exePath, err := os.Executable()
	if err != nil {
		log.Fatal("Error obteniendo ruta del ejecutable:", err)
	}

	//? Crear base de datos sqlite si es necesario
	db, err := connexionDB.CreateBaseDatabase(exePath)
	if err != nil {
		log.Fatal("Error creando base de datos:", err)
	}

	//! Iniciar docker compose para grafana
	err = connexionDB.Init_compose_grafana(exePath)
	if err != nil {
		log.Fatal("Error iniciando docker compose:", err)
	}

	//! Cargar módulos del kernel
	kernelmodules.LoadModules()

	//! Loop principal

	//* Canal para capturar señales del sistema operativo y detener el daemon correctamente
	sigs := make(chan os.Signal, 1)
	signal.Notify(sigs, syscall.SIGINT, syscall.SIGTERM)

	// Se define el ticker de 20 segundos
	ticker := time.NewTicker(20 * time.Second)
	// 'defer ticker.Stop()' asegura que el temporizador se detenga correctamente cuando el programa termine.
	defer ticker.Stop()

loop:
	// Se lee el archivo de proc cada 20 segundos a través de un for select
	for {
		select {
		case <-ticker.C:
			// Este caso se ejecuta cada vez que el ticker genera un evento (cada 20 segundos).
			lectura_sysinfo, err := utils.Readproc("/proc/sysinfo_so1_202300638")
			if err != nil {
				fmt.Println(err)
				return
			}

			// Leer información de procesos
			lectura_continfo, err := utils.Readproc("/proc/continfo_so1_202300638")
			if err != nil {
				fmt.Println(err)
				return
			}

			// Extraer los valores directamente del map de sysinfo (memoria y CPU)
			totalram := int64(lectura_sysinfo["Totalram"].(float64))
			freeram := int64(lectura_sysinfo["Freeram"].(float64))
			procs := int(lectura_sysinfo["Procs"].(float64))

			// Extraer valores de CPU del mismo módulo sysinfo
			cpuUser := int64(lectura_sysinfo["cpu_user"].(float64))
			cpuSystem := int64(lectura_sysinfo["cpu_system"].(float64))
			cpuIdle := int64(lectura_sysinfo["cpu_idle"].(float64))

			// Insertar una sola fila con los valores del sistema
			_, err = db.Exec("INSERT INTO registros (total_ram, ram_libre, total_procesos, created_at) VALUES (?, ?, ?, ?)",
				totalram, freeram, procs, time.Now().UnixMilli())
			if err != nil {
				// Si ocurre un error al insertar, se registra en los logs.
				log.Println("Error insertando:", err)
			}

			_, err = db.Exec("INSERT INTO cpu_metrics (cpu_user, cpu_system, cpu_idle, created_at) VALUES (?, ?, ?, ?)",
				cpuUser, cpuSystem, cpuIdle, time.Now().UnixMilli())
			if err != nil {
				// Si ocurre un error al insertar, se registra en los logs.
				log.Println("Error insertando métricas de CPU:", err)
			}

			// Insertar información de procesos
			if processes, ok := lectura_continfo["Processes"].([]interface{}); ok {
				timestamp := time.Now().UnixMilli()
				for _, proc := range processes {
					if p, ok := proc.(map[string]interface{}); ok {
						pid := int(p["PID"].(float64))
						name, _ := p["Name"].(string)
						cmdline, _ := p["Cmdline"].(string)
						vsz := int64(p["vsz"].(float64))
						rss := int64(p["rss"].(float64))
						memUsage := p["Memory_Usage"].(float64)
						cpuUsage := p["CPU_Usage"].(float64)
						state, _ := p["State"].(string)

						_, err = db.Exec(`INSERT INTO processes (pid, name, cmdline, vsz, rss, memory_usage, cpu_usage, state, created_at) 
							VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)`,
							pid, name, cmdline, vsz, rss, memUsage, cpuUsage, state, timestamp)
						if err != nil {
							log.Println("Error insertando proceso:", err)
						}
					}
				}
				log.Printf("Insertados %d procesos en la base de datos\n", len(processes))
			}

		case <-sigs:
			// Este caso se ejecuta cuando se recibe una señal de interrupción o terminación.
			// Detiene el daemon y sale del bucle.
			log.Println("Daemon detenido.")
			break loop
		}
	}

}
