package main

import (
	"log"
	"os"
	"time"
)

func main() {

	// 1. Crear grafana y sqlite y hacer la conexion

	// 2. Crear cronjob

	// 3. Cargar e iniciar los modulos de kernel

	// 4. Iniciar daemon

	// Abrir archivo de log
	f, err := os.OpenFile("/var/log/mydaemon.log", os.O_APPEND|os.O_CREATE|os.O_WRONLY, 0644)
	if err != nil {
		panic(err)
	}
	defer f.Close()
	log.SetOutput(f)

	log.Println("Daemon iniciado")

	for {

		//* Codigo para la lectua de los /proc

		//* Toma de desiciones para matar procesos y contenedores

		//* Almacenar resultados en la base de datos

		log.Println("Daemon sigue vivo...")
		time.Sleep(5 * time.Second)
	}

	//* Finalizar daemon
}
