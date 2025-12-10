package main

import (
	"database/sql"
	"log"
	"math/rand"
	"os"
	"os/signal"
	"path/filepath"
	"syscall"
	"time"

	_ "github.com/mattn/go-sqlite3"
)

type Container struct {
	Name   string
	CPU    float64
	Memory float64
	Status string
}

func main() {
	rand.Seed(time.Now().UnixNano())

	// Obtener directorio del ejecutable
	exePath, err := os.Executable()
	if err != nil {
		log.Fatal("Error obteniendo ruta del ejecutable:", err)
	}
	exeDir := filepath.Dir(exePath)

	// Crear ruta absoluta para la DB
	dbPath := filepath.Join(filepath.Dir(exeDir), "containers.db")
	log.Println("Usando base de datos en:", dbPath)

	// IMPORTANTE: Eliminar si existe como directorio
	if info, err := os.Stat(dbPath); err == nil && info.IsDir() {
		log.Println("containers.db es un directorio, eliminando...")
		os.RemoveAll(dbPath)
	}

	// Asegurar que el archivo se cree (método 1: crear archivo vacío)
	if _, err := os.Stat(dbPath); os.IsNotExist(err) {
		log.Println("Creando archivo de base de datos...")
		file, err := os.Create(dbPath)
		if err != nil {
			log.Fatal("Error creando archivo DB:", err)
		}
		file.Close()
		log.Println("Archivo containers.db creado")
	}

	// Conectar a SQLite
	db, err := sql.Open("sqlite3", dbPath)
	if err != nil {
		log.Fatal("Error abriendo base de datos:", err)
	}
	defer db.Close()

	// Verificar que la conexión funciona (esto también crea el archivo si no existe)
	if err := db.Ping(); err != nil {
		log.Fatal("Error conectando a la base de datos:", err)
	}
	log.Println("Conexión a base de datos establecida")

	// Crear tabla si no existe
	createTable := `
	CREATE TABLE IF NOT EXISTS containers (
		id INTEGER PRIMARY KEY AUTOINCREMENT,
		name TEXT,
		cpu REAL,
		memory REAL,
		status TEXT,
		created_at INTEGER
	);`
	_, err = db.Exec(createTable)
	if err != nil {
		log.Fatal("Error creando tabla:", err)
	}

	log.Println("Base de datos inicializada correctamente")

	// Canal para señales del sistema
	sigs := make(chan os.Signal, 1)
	signal.Notify(sigs, syscall.SIGINT, syscall.SIGTERM)

	log.Println("Daemon iniciado. Generando datos cada 20 segundos...")

	ticker := time.NewTicker(20 * time.Second)
	defer ticker.Stop()

loop:
	for {
		select {
		case <-ticker.C:
			containers := generateRandomContainers()
			for _, c := range containers {
				_, err := db.Exec("INSERT INTO containers (name, cpu, memory, status, created_at) VALUES (?, ?, ?, ?, ?)",
					c.Name, c.CPU, c.Memory, c.Status, time.Now().UnixMilli())
				if err != nil {
					log.Println("Error insertando:", err)
				} else {
					log.Printf("Insertado: %s (CPU: %.2f%%, MEM: %.2fMB, Estado: %s)\n",
						c.Name, c.CPU, c.Memory, c.Status)
				}
			}
		case <-sigs:
			log.Println(" Daemon detenido.")
			break loop
		}
	}
}

func generateRandomContainers() []Container {
	names := []string{"nginx", "redis", "mysql", "golang-app", "nodejs-app", "python-app", "java-app", "ruby-app", "postgres", "mongodb", "ubuntu", "alpine"}
	statuses := []string{"running", "stopped", "paused", "restarting"}

	n := rand.Intn(4) + 1
	var containers []Container
	for i := 0; i < n; i++ {
		containers = append(containers, Container{
			Name:   names[rand.Intn(len(names))],
			CPU:    rand.Float64() * 100,
			Memory: rand.Float64() * 512,
			Status: statuses[rand.Intn(len(statuses))],
		})
	}
	return containers
}
