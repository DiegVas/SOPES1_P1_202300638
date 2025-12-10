#!/bin/bash

set -e

DAEMON_DIR="./daemon"
GRAFANA_DIR="./grafana"
DB_FILE="containers.db"
SERVICE_FILE="mydaemon.service"
PROJECT_ROOT="$(pwd)"

echo "=========================================="
echo "FASE 1: LIMPIEZA COMPLETA"
echo "=========================================="

# Detener servicios
echo "[INFO] Deteniendo servicios..."
sudo systemctl stop mydaemon 2>/dev/null || echo "[INFO] Daemon no está corriendo"
sudo systemctl disable mydaemon 2>/dev/null || echo "[INFO] Daemon no está habilitado"

# Detener docker-compose
if [ -f "$GRAFANA_DIR/docker-compose.yml" ]; then
    echo "[INFO] Deteniendo contenedores..."
    if command -v docker-compose &> /dev/null; then
        (cd "$GRAFANA_DIR" && docker-compose down -v 2>/dev/null) || true
    else
        (cd "$GRAFANA_DIR" && docker compose down -v 2>/dev/null) || true
    fi
fi

# Limpiar TODAS las instancias de containers.db
echo "[INFO] Limpiando bases de datos en TODOS los directorios..."
for db_path in "$DB_FILE" "$DAEMON_DIR/$DB_FILE" "$GRAFANA_DIR/$DB_FILE" "daemon/$DB_FILE"; do
    if [ -e "$db_path" ]; then
        if [ -d "$db_path" ]; then
            echo "[INFO] $db_path es un DIRECTORIO (corrupto), eliminando..."
            sudo rm -rf "$db_path"
        else
            echo "[INFO] Eliminando archivo $db_path"
            sudo rm -f "$db_path"
        fi
    fi
done

# Limpiar binarios
[ -f "daemon" ] && rm -f daemon && echo "[INFO] daemon eliminado"
[ -f "mydaemon" ] && rm -f mydaemon && echo "[INFO] mydaemon eliminado"
[ -f "$DAEMON_DIR/mydaemon" ] && rm -f "$DAEMON_DIR/mydaemon" && echo "[INFO] daemon/mydaemon eliminado"

# Limpiar datos de Grafana
echo "[INFO] Limpiando datos de Grafana..."
sudo rm -rf "$GRAFANA_DIR/grafana-data"
mkdir -p "$GRAFANA_DIR/grafana-data"
sudo chown -R $USER:$USER "$GRAFANA_DIR/grafana-data"

echo ""
echo "=========================================="
echo "FASE 2: CONSTRUCCIÓN DEL DAEMON"
echo "=========================================="

[ ! -d "$DAEMON_DIR" ] && mkdir -p "$DAEMON_DIR" && echo "[INFO] Directorio daemon/ creado"

cd "$DAEMON_DIR"

# Configurar Go
export GOPROXY=direct
export GOSUMDB=off

# Inicializar módulo
if [ ! -f "go.mod" ]; then
    go mod init mydaemon
    echo "[INFO] Módulo Go inicializado"
fi

# Verificar que existe main.go
if [ ! -f "main.go" ]; then
    echo "[ERROR] No se encontró main.go en $DAEMON_DIR"
    cd ..
    exit 1
fi

# Descargar dependencias
echo "[INFO] Descargando dependencias..."
for i in {1..3}; do
    if go get -v github.com/mattn/go-sqlite3; then
        echo "[INFO] Dependencias descargadas"
        break
    else
        echo "[WARN] Intento $i/3 falló..."
        sleep 2
        [ $i -eq 3 ] && echo "[ERROR] Fallo después de 3 intentos" && cd .. && exit 1
    fi
done

go mod tidy

# Construir binario
echo "[INFO] Compilando daemon..."
go build -o mydaemon main.go

if [ ! -f "mydaemon" ]; then
    echo "[ERROR] No se generó el binario mydaemon"
    cd ..
    exit 1
fi

echo "[INFO] Daemon compilado exitosamente"
cd ..

echo ""
echo "=========================================="
echo "FASE 3: INSTALACIÓN DEL SERVICIO SYSTEMD"
echo "=========================================="

# Crear archivo .service mejorado
cat > /tmp/$SERVICE_FILE <<EOF
[Unit]
Description=Daemon de monitoreo de contenedores
After=network.target

[Service]
Type=simple
ExecStart=$PROJECT_ROOT/$DAEMON_DIR/mydaemon
WorkingDirectory=$PROJECT_ROOT/$DAEMON_DIR
Restart=always
RestartSec=10

[Install]
WantedBy=multi-user.target
EOF

sudo mv /tmp/$SERVICE_FILE /etc/systemd/system/$SERVICE_FILE
sudo systemctl daemon-reload
echo "[INFO] Servicio systemd instalado"

# Iniciar el daemon
echo "[INFO] Iniciando daemon..."
sudo systemctl start mydaemon
sleep 3

# Verificar que el daemon está corriendo
if sudo systemctl is-active --quiet mydaemon; then
    echo "[INFO] ✓ Daemon iniciado correctamente"
else
    echo "[ERROR] ✗ Daemon falló al iniciar"
    sudo journalctl -u mydaemon -n 20 --no-pager
    exit 1
fi

# Habilitar para inicio automático
sudo systemctl enable mydaemon
echo "[INFO] Daemon habilitado para inicio automático"

echo ""
echo "=========================================="
echo "FASE 4: VERIFICACIÓN DE LA BASE DE DATOS"
echo "=========================================="

# Esperar a que se cree la DB
echo "[INFO] Esperando a que se cree la base de datos..."
for i in {1..10}; do
    if [ -f "$DAEMON_DIR/$DB_FILE" ] && [ ! -d "$DAEMON_DIR/$DB_FILE" ]; then
        echo "[INFO] ✓ Base de datos creada correctamente"
        ls -lh "$DAEMON_DIR/$DB_FILE"
        
        # Verificar permisos
        if [ -r "$DAEMON_DIR/$DB_FILE" ]; then
            echo "[INFO] ✓ Archivo legible"
        else
            echo "[WARN] Ajustando permisos..."
            chmod 644 "$DAEMON_DIR/$DB_FILE"
        fi
        
        # Verificar integridad
        if sqlite3 "$DAEMON_DIR/$DB_FILE" "SELECT count(*) FROM containers;" &>/dev/null; then
            echo "[INFO] ✓ Base de datos SQLite válida"
        else
            echo "[ERROR] Base de datos corrupta"
            exit 1
        fi
        
        break
    fi
    echo "[INFO] Esperando... ($i/10)"
    sleep 2
done

if [ ! -f "$DAEMON_DIR/$DB_FILE" ]; then
    echo "[ERROR] La base de datos no se creó después de 20 segundos"
    echo "[INFO] Logs del daemon:"
    sudo journalctl -u mydaemon -n 30 --no-pager
    exit 1
fi

echo ""
echo "=========================================="
echo "FASE 5: DOCKER COMPOSE"
echo "=========================================="

if [ ! -d "$GRAFANA_DIR" ]; then
    echo "[ERROR] No se encontró $GRAFANA_DIR"
    exit 1
fi


cd "$GRAFANA_DIR"
echo "[INFO] Iniciando Grafana..."
if command -v docker-compose &> /dev/null; then
    docker-compose up -d
else
    docker compose up -d
fi

# Esperar a que Grafana esté listo
echo "[INFO] Esperando a que Grafana inicie..."
for i in {1..30}; do
    if curl -s http://localhost:3000 > /dev/null 2>&1; then
        echo "[INFO] ✓ Grafana está corriendo"
        break
    fi
    sleep 1
done

cd ..

echo ""
echo "=========================================="
echo " DESPLIEGUE COMPLETADO EXITOSAMENTE"
echo "=========================================="
========================"