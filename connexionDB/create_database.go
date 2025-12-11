package connexionDB

import (
	"database/sql"
	"log"
	"os"
	"path/filepath"

	_ "github.com/mattn/go-sqlite3"
)

//* CreateDatabase crea la base de datos SQLite y la tabla necesaria.

func CreateBaseDatabase(exePath string) (*sql.DB, error) {

	exeDir := filepath.Dir(exePath)

	// Crear ruta absoluta para la DB
	dbPath := filepath.Join(exeDir, "containers.db")
	log.Println("Usando base de datos en:", dbPath)

	// IMPORTANTE: Eliminar si existe como directorio
	if info, err := os.Stat(dbPath); err == nil && info.IsDir() {
		log.Println("containers.db es un directorio, eliminando...")
		os.RemoveAll(dbPath)
	}

	// Asegurar que el archivo se cree
	if _, err := os.Stat(dbPath); os.IsNotExist(err) {
		log.Println("Creando archivo de base de datos...")
		file, err := os.Create(dbPath)
		if err != nil {
			log.Fatal("Error creando archivo DB:", err)
		}
		file.Close()
		log.Println("Archivo containers.db creado")
	}

	// Conexión a SQLite
	db, err := sql.Open("sqlite3", dbPath)
	if err != nil {
		log.Fatal("Error abriendo base de datos:", err)
	}
	// NO cerrar la base de datos aquí, se debe mantener abierta para el programa

	// Crear tabla si no existe
	createTable := `
	CREATE TABLE IF NOT EXISTS registros (
		id INTEGER PRIMARY KEY AUTOINCREMENT,
		total_ram REAL,
		ram_libre REAL,
		total_procesos REAL,
		created_at INTEGER
	);`
	_, err = db.Exec(createTable)
	if err != nil {
		log.Fatal("Error creando tabla:", err)
		return nil, err
	}

	// Crear tabla para métricas de CPU
	createCPUTable := `
	CREATE TABLE IF NOT EXISTS cpu_metrics (
		id INTEGER PRIMARY KEY AUTOINCREMENT,
		cpu_user INTEGER,
		cpu_system INTEGER,
		cpu_idle INTEGER,
		created_at INTEGER
	);`
	_, err = db.Exec(createCPUTable)
	if err != nil {
		log.Fatal("Error creando tabla cpu_metrics:", err)
		return nil, err
	}

	// Crear tabla para procesos
	createProcessTable := `
	CREATE TABLE IF NOT EXISTS processes (
		id INTEGER PRIMARY KEY AUTOINCREMENT,
		pid INTEGER,
		name TEXT,
		cmdline TEXT,
		vsz INTEGER,
		rss INTEGER,
		memory_usage REAL,
		cpu_usage REAL,
		state TEXT,
		created_at INTEGER
	);`
	_, err = db.Exec(createProcessTable)
	if err != nil {
		log.Fatal("Error creando tabla processes:", err)
		return nil, err
	}

	return db, nil

}
