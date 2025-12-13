package connexionDB

import (
	"database/sql"
	"log"
	"os"
	"path/filepath"
	"time"

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

	// Asegurar que el archivo se cree con permisos adecuados
	if _, err := os.Stat(dbPath); os.IsNotExist(err) {
		log.Println("Creando archivo de base de datos...")
		file, err := os.Create(dbPath)
		if err != nil {
			log.Fatal("Error creando archivo DB:", err)
		}
		file.Close()

		// Establecer permisos de lectura/escritura para todos
		if err := os.Chmod(dbPath, 0666); err != nil {
			log.Printf("Advertencia: No se pudieron establecer permisos en DB: %v", err)
		}

		log.Println("Archivo containers.db creado")
	}

	// Verificar y corregir permisos del archivo existente
	if info, err := os.Stat(dbPath); err == nil {
		log.Printf("Permisos actuales de containers.db: %v", info.Mode().Perm())

		// Asegurar permisos de lectura/escritura
		if err := os.Chmod(dbPath, 0666); err != nil {
			log.Printf("Error al cambiar permisos: %v", err)
		} else {
			log.Println("Permisos de containers.db actualizados a 0666")
		}
	}

	// Verificar permisos del directorio
	if dirInfo, err := os.Stat(exeDir); err == nil {
		log.Printf("Permisos del directorio: %v", dirInfo.Mode().Perm())
		if dirInfo.Mode().Perm()&0200 == 0 {
			log.Println("⚠️ Advertencia: El directorio no tiene permisos de escritura")
		}
	}

	// Conexión a SQLite con parámetros adicionales para evitar problemas de bloqueo
	dbConnectionString := dbPath + "?_journal_mode=WAL&_busy_timeout=5000"
	log.Println("Conectando a base de datos:", dbPath)
	db, err := sql.Open("sqlite3", dbConnectionString)
	if err != nil {
		log.Fatal("Error abriendo base de datos:", err)
	}

	// Configurar parámetros de conexión
	db.SetMaxOpenConns(1) // SQLite funciona mejor con una sola conexión de escritura

	// Probar que podemos escribir en la base de datos
	_, err = db.Exec("PRAGMA journal_mode=WAL;")
	if err != nil {
		log.Printf("⚠️ Advertencia: No se pudo establecer WAL mode: %v", err)
	}

	// Dar tiempo para que SQLite cree los archivos WAL
	time.Sleep(100 * time.Millisecond)

	// Asegurar permisos de todos los archivos de SQLite (incluyendo WAL y SHM)
	sqliteFiles := []string{
		dbPath,
		dbPath + "-wal",
		dbPath + "-shm",
	}

	for _, file := range sqliteFiles {
		if _, err := os.Stat(file); err == nil {
			if err := os.Chmod(file, 0666); err != nil {
				log.Printf("⚠️ No se pudieron establecer permisos en %s: %v", filepath.Base(file), err)
			} else {
				log.Printf("✓ Permisos establecidos en %s", filepath.Base(file))
			}
		}
	}

	// NO cerrar la base de datos aquí, se debe mantener abierta para el programa

	// Crear tabla si no existe
	createTable := `
	CREATE TABLE IF NOT EXISTS registros (
		id INTEGER PRIMARY KEY AUTOINCREMENT,
		total_ram REAL,
		ram_libre REAL,
		ram_usada REAL,
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

	// Crear tabla para contenedores Docker
	createContainersTable := `
	CREATE TABLE IF NOT EXISTS containers (
		id INTEGER PRIMARY KEY AUTOINCREMENT,
		container_id TEXT UNIQUE,
		container_name TEXT,
		image_name TEXT,
		status TEXT,
		ram_usage REAL DEFAULT 0,
		cpu_usage REAL DEFAULT 0,
		created_at INTEGER,
		updated_at INTEGER
	);`
	_, err = db.Exec(createContainersTable)
	if err != nil {
		log.Fatal("Error creando tabla containers:", err)
		return nil, err
	}

	// Crear tabla para contenedores eliminados
	createDeletedContainersTable := `
	CREATE TABLE IF NOT EXISTS deleted_containers (
		id INTEGER PRIMARY KEY AUTOINCREMENT,
		container_id TEXT,
		container_name TEXT,
		image_name TEXT,
		deletion_reason TEXT,
		ram_usage REAL DEFAULT 0,
		cpu_usage REAL DEFAULT 0,
		created_at INTEGER,
		deleted_at INTEGER
	);`
	_, err = db.Exec(createDeletedContainersTable)
	if err != nil {
		log.Fatal("Error creando tabla deleted_containers:", err)
		return nil, err
	}

	return db, nil

}

// CleanupOldData elimina datos más antiguos que X horas para evitar que la BD crezca infinitamente
func CleanupOldData(db *sql.DB, hoursToKeep int) error {
	// Calcular timestamp límite (en milisegundos)
	cutoffTime := time.Now().Add(-time.Duration(hoursToKeep) * time.Hour).UnixMilli()

	// Limpiar tabla registros
	result, err := db.Exec("DELETE FROM registros WHERE created_at < ?", cutoffTime)
	if err != nil {
		return err
	}
	rows, _ := result.RowsAffected()
	if rows > 0 {
		log.Printf("Limpieza BD: Eliminadas %d filas antiguas de registros", rows)
	}

	// Limpiar tabla cpu_metrics
	result, err = db.Exec("DELETE FROM cpu_metrics WHERE created_at < ?", cutoffTime)
	if err != nil {
		return err
	}
	rows, _ = result.RowsAffected()
	if rows > 0 {
		log.Printf("Limpieza BD: Eliminadas %d filas antiguas de cpu_metrics", rows)
	}

	// Limpiar tabla processes
	result, err = db.Exec("DELETE FROM processes WHERE created_at < ?", cutoffTime)
	if err != nil {
		return err
	}
	rows, _ = result.RowsAffected()
	if rows > 0 {
		log.Printf("Limpieza BD: Eliminadas %d filas antiguas de processes", rows)
	}

	// Limpiar tabla deleted_containers
	result, err = db.Exec("DELETE FROM deleted_containers WHERE deleted_at < ?", cutoffTime)
	if err != nil {
		return err
	}
	rows, _ = result.RowsAffected()
	if rows > 0 {
		log.Printf("Limpieza BD: Eliminadas %d filas antiguas de deleted_containers", rows)
	}

	// Ejecutar VACUUM para liberar espacio en disco
	_, err = db.Exec("VACUUM")
	if err != nil {
		log.Printf("Advertencia: No se pudo ejecutar VACUUM: %v", err)
	} else {
		log.Println("Limpieza BD: VACUUM completado")
	}

	return nil
}
