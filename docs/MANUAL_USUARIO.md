# MANUAL DE USUARIO - SISTEMA DE MONITOREO DE CONTENEDORES

## Proyecto SOPES1 - Carnet: 202300638

---

## Tabla de Contenidos

1. [Introducción](#1-introducción)
2. [Requisitos del Sistema](#2-requisitos-del-sistema)
3. [Guía de Instalación](#3-guía-de-instalación)
4. [Arquitectura del Sistema](#4-arquitectura-del-sistema)
5. [Inicio del Sistema](#5-inicio-del-sistema)
6. [Acceso al Dashboard de Grafana](#6-acceso-al-dashboard-de-grafana)
7. [Ejemplos de Uso](#7-ejemplos-de-uso)
8. [Preguntas Frecuentes](#8-preguntas-frecuentes)
9. [Solución de Problemas](#9-solución-de-problemas)

---

## 1. Introducción

### ¿Qué es este sistema?

El Sistema de Monitoreo de Contenedores es una herramienta que permite visualizar en tiempo real el estado y consumo de recursos de contenedores Docker ejecutándose en su sistema Linux.

### ¿Para qué sirve?

- **Monitorear recursos del sistema**: Ver uso de RAM, CPU, espacio en disco
- **Supervisar contenedores Docker**: Conocer qué contenedores están activos y cuántos recursos consumen
- **Visualizar históricos**: Ver gráficas del comportamiento del sistema a lo largo del tiempo
- **Detectar problemas**: Identificar contenedores que consumen demasiados recursos

### ¿Quién puede usar este sistema?

Este sistema está diseñado para:

- Administradores de sistemas Linux
- Desarrolladores que trabajan con Docker
- Estudiantes de sistemas operativos
- Cualquier persona que necesite monitorear contenedores

---

## 2. Requisitos del Sistema

### 2.1 Hardware Mínimo Requerido

| Componente              | Mínimo                     | Recomendado     |
| ----------------------- | -------------------------- | --------------- |
| **Procesador**          | 2 núcleos                  | 4 núcleos o más |
| **Memoria RAM**         | 4 GB                       | 8 GB o más      |
| **Espacio en Disco**    | 10 GB libres               | 20 GB o más     |
| **Conexión a Internet** | Requerida para instalación | Requerida       |

### 2.2 Software Requerido

| Software              | Versión Mínima           | Propósito               |
| --------------------- | ------------------------ | ----------------------- |
| **Sistema Operativo** | Ubuntu 20.04 / Debian 11 | Linux compatible        |
| **Kernel Linux**      | 5.0 o superior           | Para módulos del kernel |
| **Docker**            | 20.10 o superior         | Gestión de contenedores |
| **Docker Compose**    | 2.0 o superior           | Orquestación            |
| **Go (Golang)**       | 1.19 o superior          | Compilación del daemon  |

### 2.3 Verificar Requisitos

Puede verificar si su sistema cumple los requisitos ejecutando:

```bash
# Verificar versión del sistema
cat /etc/os-release

# Verificar versión del kernel
uname -r

# Verificar Docker
docker --version

# Verificar Docker Compose
docker compose version

# Verificar Go
go version
```

**Ejemplo de salida correcta:**

```
PRETTY_NAME="Ubuntu 22.04 LTS"
6.5.0-14-generic
Docker version 24.0.7
Docker Compose version v2.21.0
go version go1.21.4 linux/amd64
```

---

## 3. Guía de Instalación

### 3.1 Instalación Completa Paso a Paso

#### Paso 1: Actualizar el Sistema

```bash
# Actualizar lista de paquetes
sudo apt update

# Actualizar paquetes instalados
sudo apt upgrade -y
```

**Tiempo estimado:** 5-10 minutos

---

#### Paso 2: Instalar Dependencias

```bash
# Instalar herramientas de compilación
sudo apt install -y build-essential

# Instalar headers del kernel
sudo apt install -y linux-headers-$(uname -r)

# Instalar Go
sudo apt install -y golang-go

# Instalar Docker
sudo apt install -y docker.io docker-compose

# Instalar herramientas adicionales
sudo apt install -y git curl jq
```

**Tiempo estimado:** 10-15 minutos

**Verificación:**

```bash
# Debería mostrar las versiones instaladas
gcc --version
go version
docker --version
```

---

#### Paso 3: Configurar Docker

```bash
# Agregar su usuario al grupo docker (para no usar sudo)
sudo usermod -aG docker $USER

# Iniciar servicio Docker
sudo systemctl start docker

# Habilitar Docker al inicio
sudo systemctl enable docker

# Verificar que Docker funciona
docker run hello-world
```

**⚠️ IMPORTANTE:** Después de agregar su usuario al grupo docker, debe cerrar sesión y volver a iniciarla para que los cambios surtan efecto.

---

#### Paso 4: Descargar el Proyecto

```bash
# Ir al directorio de documentos (o donde prefiera)
cd ~/Documentos

# Clonar o descargar el proyecto
# (Ajustar según su método de obtención del código)

# Ingresar al directorio del proyecto
cd SOPES1_P1_202300638
```

---

#### Paso 5: Compilar el Proyecto

```bash
# Dar permisos de ejecución al script de compilación
chmod +x build.sh

# Ejecutar compilación
./build.sh
```

**Salida esperada:**

```
=== Iniciando Compilación ===

[1/3] Compilando computer_metric...
✓ computer_metric compilado

[2/3] Compilando process_metric...
✓ process_metric compilado

[3/3] Compilando daemon Go...
✓ Daemon compilado

=== Compilación Completada ===
Para ejecutar: sudo ./main
```

**Tiempo estimado:** 2-5 minutos

---

#### Paso 6: Verificar la Compilación

```bash
# Verificar que los archivos se compilaron correctamente
ls -lh kernel_modules/metric_computer_module/computer_metric.ko
ls -lh kernel_modules/metric_process_module/process_metric.ko
ls -lh main
```

**Salida esperada:**

```
-rw-r--r-- 1 user user 16K computer_metric.ko
-rw-r--r-- 1 user user 24K process_metric.ko
-rwxr-xr-x 1 user user 12M main
```

---

### 3.2 Configuración Inicial

#### Crear Directorios Necesarios

```bash
# El sistema creará automáticamente estos directorios al iniciarse
# Pero puede crearlos manualmente si lo desea:

mkdir -p database
mkdir -p logs
mkdir -p connexionDB/grafana-data
```

---

## 4. Arquitectura del Sistema

### 4.1 ¿Cómo Funciona el Sistema?

El sistema está compuesto por tres partes principales que trabajan juntas:

```
┌─────────────────────────────────────────────────────┐
│                    KERNEL LINUX                      │
│  ┌─────────────────┐      ┌──────────────────┐     │
│  │ Módulo Computer │      │ Módulo Process   │     │
│  │ (Lee RAM/CPU)   │      │ (Lee Procesos)   │     │
│  └────────┬────────┘      └─────────┬────────┘     │
│           │                          │              │
│           ▼                          ▼              │
│      /proc/sysinfo           /proc/continfo         │
└─────────────────────────────────────────────────────┘
                      │
                      │ El daemon lee estos archivos
                      ▼
┌─────────────────────────────────────────────────────┐
│              DAEMON (Programa Principal)             │
│  • Lee información cada 5 segundos                   │
│  • Procesa y almacena datos                         │
│  • Gestiona base de datos SQLite                    │
└──────────────────┬──────────────────────────────────┘
                   │
                   ▼
┌─────────────────────────────────────────────────────┐
│                   GRAFANA                            │
│  • Visualiza datos en gráficas                      │
│  • Interfaz web accesible                           │
│  • Actualización en tiempo real                     │
└─────────────────────────────────────────────────────┘
```

### 4.2 Componentes del Sistema

#### 1. Módulos del Kernel (Invisible para el usuario)

Los módulos son pequeños programas que se insertan en el núcleo de Linux para obtener información directamente del sistema operativo.

- **Módulo Computer:** Obtiene información de memoria RAM y CPU
- **Módulo Process:** Obtiene información de todos los procesos y contenedores

**Analogía:** Son como sensores que miden constantemente el pulso del sistema.

---

#### 2. Daemon (Programa Principal)

El daemon es el "cerebro" del sistema. Se ejecuta en segundo plano y:

- Lee la información de los módulos
- La procesa y organiza
- La guarda en una base de datos
- Coordina todo el sistema

**Analogía:** Es como un doctor que constantemente revisa los sensores y anota los resultados en un historial médico.

---

#### 3. Base de Datos SQLite

Almacena todo el histórico de información para poder ver:

- Cómo ha cambiado el uso de recursos en el tiempo
- Cuándo se crearon o eliminaron contenedores
- Tendencias y patrones de uso

---

#### 4. Grafana (Dashboard)

Es la interfaz visual donde usted puede ver toda la información en forma de:

- Gráficas de líneas
- Tablas
- Indicadores
- Alertas

**Analogía:** Es como el tablero de instrumentos de un auto, donde ve velocidad, temperatura, gasolina, etc.

---

### 4.3 Flujo de Datos

```
1. Los MÓDULOS extraen datos del sistema cada vez que se solicitan
                         ↓
2. El DAEMON lee esos datos cada 5 segundos
                         ↓
3. El DAEMON guarda los datos en la BASE DE DATOS
                         ↓
4. GRAFANA lee la base de datos y muestra gráficas actualizadas
                         ↓
5. USTED ve las gráficas en su navegador web
```

---

## 5. Inicio del Sistema

### 5.1 Iniciar el Sistema por Primera Vez

Siga estos pasos en orden para iniciar el sistema correctamente:

#### Paso 1: Cargar los Módulos del Kernel

```bash
# Navegar al directorio del proyecto
cd ~/Documentos/SOPES1_P1_202300638

# Cargar módulo de información del sistema
sudo insmod kernel_modules/metric_computer_module/computer_metric.ko

# Cargar módulo de procesos
sudo insmod kernel_modules/metric_process_module/process_metric.ko
```

**Verificar que se cargaron correctamente:**

```bash
# Debe mostrar los dos módulos
lsmod | grep -E "computer_metric|process_metric"
```

**Salida esperada:**

```
process_metric         16384  0
computer_metric        16384  0
```

---

#### Paso 2: Verificar Archivos en /proc

```bash
# Verificar que se crearon los archivos virtuales
ls -l /proc/sysinfo_so1_202300638
ls -l /proc/continfo_so1_202300638
```

**Salida esperada:**

```
-r--r--r-- 1 root root 0 /proc/sysinfo_so1_202300638
-r--r--r-- 1 root root 0 /proc/continfo_so1_202300638
```

**Probar lectura:**

```bash
# Ver información del sistema (debe mostrar JSON)
cat /proc/sysinfo_so1_202300638
```

---

#### Paso 3: Iniciar el Daemon

```bash
# Opción 1: Ejecutar en primer plano (para ver logs)
sudo ./main

# Opción 2: Ejecutar en segundo plano (recomendado)
sudo nohup ./main > logs/daemon.log 2>&1 &
```

**Verificar que está ejecutándose:**

```bash
ps aux | grep main
```

---

#### Paso 4: Verificar Grafana

```bash
# Verificar que Grafana esté corriendo
docker ps | grep grafana
```

**Salida esperada:**

```
abc123def456  grafana/grafana  Up 2 minutes  0.0.0.0:3000->3000/tcp  grafana_monitoring
```

---

### 5.2 Detener el Sistema

Para detener el sistema de forma segura:

```bash
# 1. Detener el daemon
sudo pkill -f "main"

# 2. Descargar módulos del kernel
sudo rmmod process_metric
sudo rmmod computer_metric

# 3. Detener Grafana (opcional)
docker compose -f connexionDB/docker-compose.yml down
```

---

## 6. Acceso al Dashboard de Grafana

### 6.1 Abrir Grafana en el Navegador

#### Paso 1: Abrir su Navegador Web

Puede usar cualquier navegador moderno:

- Google Chrome
- Mozilla Firefox
- Microsoft Edge
- Safari

---

#### Paso 2: Acceder a la URL de Grafana

En la barra de direcciones, escriba:

```
http://localhost:3000
```

O si está accediendo desde otra computadora en la red local:

```
http://[IP-DEL-SERVIDOR]:3000
```

**[CAPTURA: Página de Login de Grafana]**

_Espacio para captura de pantalla_

---

### 6.2 Iniciar Sesión en Grafana

#### Credenciales de Acceso

```
Usuario:    admin
Contraseña: admin
```

**Pasos:**

1. Ingrese `admin` en el campo "Usuario" (Email or username)
2. Ingrese `admin` en el campo "Contraseña" (Password)
3. Haga clic en "Log in"

**[CAPTURA: Formulario de Login]**

_Espacio para captura de pantalla_

---

#### Primera Vez - Cambiar Contraseña

La primera vez que inicie sesión, Grafana le pedirá cambiar la contraseña:

1. **Opción 1:** Cambiar la contraseña (recomendado)

   - Ingrese una nueva contraseña segura
   - Confirme la contraseña
   - Haga clic en "Submit"

2. **Opción 2:** Saltar (Skip)
   - Haga clic en "Skip" para mantener la contraseña por defecto
   - **⚠️ No recomendado en producción**

**[CAPTURA: Cambio de Contraseña]**

_Espacio para captura de pantalla_

---

### 6.3 Interfaz Principal de Grafana

Una vez que inicie sesión, verá la página principal de Grafana.

**[CAPTURA: Home Page de Grafana]**

_Espacio para captura de pantalla_

#### Elementos de la Interfaz

```
┌────────────────────────────────────────────────────┐
│  [≡] Grafana        [+] [🔔] [⚙️] [👤]            │  ← Barra superior
├────────────────────────────────────────────────────┤
│                                                    │
│  Welcome to Grafana                               │
│                                                    │
│  ┌─────────────┐  ┌─────────────┐               │
│  │ Dashboards  │  │ Data Sources│               │
│  └─────────────┘  └─────────────┘               │
│                                                    │
│  Recent dashboards                                 │
│  • Monitoreo de Contenedores                     │
│  • Métricas del Sistema                          │
│                                                    │
└────────────────────────────────────────────────────┘
```

**Iconos principales:**

- **[≡]** Menú lateral
- **[+]** Crear nuevo elemento
- **[🔔]** Notificaciones y alertas
- **[⚙️]** Configuración
- **[👤]** Perfil de usuario

---

### 6.4 Configurar Fuente de Datos (Data Source)

Para que Grafana pueda leer los datos del sistema, debe configurar la conexión a la base de datos.

#### Paso 1: Acceder a Configuración

1. Haga clic en el icono de **engranaje [⚙️]** en la barra lateral izquierda
2. Seleccione **"Data sources"**

**[CAPTURA: Menú de Configuración]**

_Espacio para captura de pantalla_

---

#### Paso 2: Agregar Nueva Fuente de Datos

1. Haga clic en el botón **"Add data source"**
2. Busque o seleccione **"SQLite"**

**[CAPTURA: Lista de Data Sources]**

_Espacio para captura de pantalla_

**⚠️ Nota:** Si no ve SQLite en la lista, es porque el plugin no está instalado. El sistema debería haberlo instalado automáticamente.

---

#### Paso 3: Configurar SQLite

Complete los siguientes campos:

| Campo    | Valor                                  |
| -------- | -------------------------------------- |
| **Name** | `Sistema de Monitoreo`                 |
| **Path** | `/var/lib/grafana/database/metrics.db` |

**[CAPTURA: Configuración SQLite]**

_Espacio para captura de pantalla_

1. Desplácese hasta abajo
2. Haga clic en **"Save & test"**
3. Debería aparecer un mensaje verde: **"Data source is working"**

---

### 6.5 Crear su Primer Dashboard

#### Paso 1: Crear Nuevo Dashboard

1. Haga clic en el icono **[+]** en la barra superior
2. Seleccione **"Dashboard"**
3. Haga clic en **"Add new panel"**

**[CAPTURA: Crear Dashboard]**

_Espacio para captura de pantalla_

---

#### Paso 2: Configurar Panel de Uso de RAM

**Query para RAM:**

```sql
SELECT
  timestamp as time,
  used_ram / 1024 / 1024 as "RAM Usada (MB)",
  total_ram / 1024 / 1024 as "RAM Total (MB)"
FROM system_metrics
ORDER BY timestamp DESC
LIMIT 1000
```

**Configuración del Panel:**

- **Título:** "Uso de Memoria RAM"
- **Tipo de visualización:** Time series (gráfica de líneas)
- **Eje Y:** MB (Megabytes)

**[CAPTURA: Panel de RAM]**

_Espacio para captura de pantalla_

---

#### Paso 3: Agregar Panel de Contenedores Activos

Haga clic en **"Add panel"** nuevamente.

**Query para Contenedores:**

```sql
SELECT
  name,
  status,
  cpu_percent,
  memory_percent,
  updated_at as time
FROM containers
WHERE status = 'running'
ORDER BY memory_percent DESC
```

**Configuración del Panel:**

- **Título:** "Contenedores Activos"
- **Tipo de visualización:** Table (tabla)

**[CAPTURA: Panel de Contenedores]**

_Espacio para captura de pantalla_

---

#### Paso 4: Guardar Dashboard

1. Haga clic en el icono de **disquete [💾]** en la esquina superior derecha
2. Ingrese un nombre: `"Monitoreo de Sistema"`
3. Haga clic en **"Save"**

**[CAPTURA: Guardar Dashboard]**

_Espacio para captura de pantalla_

---

### 6.6 Navegación en Grafana

#### Ver Dashboards Existentes

1. Haga clic en el icono de **cuatro cuadrados [☷]** (Dashboards)
2. Seleccione **"Browse"**
3. Verá la lista de todos sus dashboards

**[CAPTURA: Lista de Dashboards]**

_Espacio para captura de pantalla_

---

#### Refrescar Datos

Para actualizar los datos en tiempo real:

1. En la esquina superior derecha, busque el selector de tiempo
2. Haga clic en el icono de **refresco [↻]**
3. Seleccione **"5s"** para actualización cada 5 segundos

**[CAPTURA: Configuración de Refresco]**

_Espacio para captura de pantalla_

---

#### Rango de Tiempo

Para ver datos de diferentes períodos:

1. Haga clic en el selector de tiempo (ejemplo: "Last 6 hours")
2. Seleccione el rango que desee:
   - Last 5 minutes
   - Last 15 minutes
   - Last 1 hour
   - Last 6 hours
   - Last 24 hours
   - Custom range (personalizado)

**[CAPTURA: Selector de Tiempo]**

_Espacio para captura de pantalla_

---

## 7. Ejemplos de Uso

### 7.1 Caso de Uso 1: Monitorear Uso de Recursos

#### Escenario

Usted es administrador de un servidor y necesita saber si tiene suficiente memoria y CPU disponible antes de desplegar una nueva aplicación.

#### Pasos

1. **Abrir Grafana** (http://localhost:3000)
2. **Navegar al Dashboard** "Monitoreo de Sistema"
3. **Observar el panel de RAM**
   - Verde: < 70% uso (saludable)
   - Amarillo: 70-85% uso (precaución)
   - Rojo: > 85% uso (crítico)

**[CAPTURA: Dashboard con Estado Saludable]**

_Espacio para captura de pantalla_

#### Interpretación

```
Si ve:
RAM Usada: 4.2 GB / 8 GB (52%)
CPU Idle: 65%

Conclusión: ✅ Tiene suficiente capacidad para la nueva aplicación
```

---

### 7.2 Caso de Uso 2: Identificar Contenedor Problemático

#### Escenario

Su servidor está lento y necesita identificar qué contenedor está consumiendo demasiados recursos.

#### Pasos

1. **Abrir Grafana**
2. **Ver la tabla de "Contenedores Activos"**
3. **Ordenar por "memory_percent"** (hacer clic en el encabezado)

**[CAPTURA: Tabla Ordenada por Uso de Memoria]**

_Espacio para captura de pantalla_

#### Ejemplo de Resultado

| Nombre                | CPU % | Memoria %          |
| --------------------- | ----- | ------------------ |
| container_mysql_12345 | 45%   | **92%** ← Problema |
| container_nginx_67890 | 5%    | 12%                |
| container_redis_24680 | 8%    | 15%                |

#### Acción a Tomar

```bash
# Detener el contenedor problemático
docker stop container_mysql_12345

# Ver logs para investigar
docker logs container_mysql_12345

# Reiniciar con límites más bajos
docker start container_mysql_12345
```

---

### 7.3 Caso de Uso 3: Análisis de Tendencias

#### Escenario

Quiere saber si el uso de memoria ha ido aumentando con el tiempo (posible fuga de memoria).

#### Pasos

1. **Abrir Grafana**
2. **Seleccionar rango de tiempo:** "Last 24 hours"
3. **Observar la gráfica de RAM**

**[CAPTURA: Gráfica de Tendencia]**

_Espacio para captura de pantalla_

#### Interpretación

```
Patrón Normal:
RAM ▁▂▃▂▁▂▃▂▁  (fluctúa pero no crece constantemente)

Posible Fuga de Memoria:
RAM ▁▂▃▄▅▆▇█  (crece constantemente sin bajar)
```

---

### 7.4 Caso de Uso 4: Verificar Contenedores Generados

#### Escenario

Tiene configurado el sistema para generar contenedores automáticamente y quiere verificar que funciona.

#### Pasos

1. **Esperar 2-3 minutos** (el cronjob ejecuta cada minuto)
2. **Verificar en terminal:**

```bash
# Ver contenedores nuevos
docker ps --format "table {{.Names}}\t{{.Status}}" | grep container_
```

3. **Ver en Grafana:**
   - Panel de "Contenedores Activos"
   - El contador debería ir aumentando

**[CAPTURA: Aumento de Contenedores]**

_Espacio para captura de pantalla_

---

### 7.5 Caso de Uso 5: Limpiar Sistema Saturado

#### Escenario

El sistema generó demasiados contenedores y se está quedando sin recursos.

#### Síntomas

- Sistema lento
- RAM > 90%
- Disco casi lleno

#### Solución Rápida

```bash
# 1. Detener generación automática
crontab -r

# 2. Detener todos los contenedores generados
docker stop $(docker ps -q --filter "name=container_")

# 3. Eliminar contenedores detenidos
docker rm $(docker ps -aq --filter "name=container_")

# 4. Limpiar volúmenes huérfanos
docker volume prune -f

# 5. Limpiar imágenes no usadas
docker image prune -a -f
```

**Verificar en Grafana:**

- El uso de RAM debería bajar
- El número de contenedores activos debería ser 0 (o solo Grafana)

**[CAPTURA: Sistema Después de Limpieza]**

_Espacio para captura de pantalla_

---

## 8. Preguntas Frecuentes

### 8.1 Instalación y Configuración

**P: ¿Puedo instalar este sistema en Windows o macOS?**

R: No directamente. Este sistema requiere Linux porque usa módulos del kernel de Linux. Sin embargo, puede:

- Usar una máquina virtual con Linux (VirtualBox, VMware)
- Usar WSL2 en Windows (con limitaciones)
- Usar Docker Desktop (solo para la visualización)

---

**P: ¿Necesito conexión a internet después de instalar?**

R: No es necesaria para el funcionamiento del sistema, solo para:

- Descargar imágenes Docker si genera contenedores
- Actualizar el sistema
- Acceder a Grafana desde otro equipo (si usa la red)

---

**P: ¿Puedo cambiar el puerto 3000 de Grafana?**

R: Sí, edite el archivo `connexionDB/docker-compose.yml`:

```yaml
ports:
  - "8080:3000" # Usar puerto 8080 en lugar de 3000
```

Luego reinicie Grafana:

```bash
docker compose -f connexionDB/docker-compose.yml restart
```

---

### 8.2 Uso del Sistema

**P: ¿Cada cuánto se actualizan los datos?**

R: El daemon lee datos cada 5 segundos. En Grafana, puede configurar el refresco automático a 5s, 10s, 30s, etc.

---

**P: ¿Cuánto espacio en disco usa el sistema?**

R: Depende del tiempo de ejecución:

- Base de datos SQLite: ~10-50 MB por día
- Logs: ~5-10 MB por día
- Contenedores Docker: Variable (100MB - varios GB)

**Recomendación:** Limpiar datos antiguos cada semana.

---

**P: ¿Puedo monitorear contenedores creados manualmente?**

R: Sí, el sistema monitorea **todos** los contenedores Docker en el sistema, no solo los que genera automáticamente.

---

**P: ¿Los módulos del kernel son peligrosos?**

R: Los módulos están diseñados para solo **leer** información, no modifican nada. Sin embargo:

- Solo cárguelos si confía en el código fuente
- Pueden causar inestabilidad si están mal programados
- Use `sudo rmmod` para descargarlos si hay problemas

---

### 8.3 Grafana

**P: Olvidé mi contraseña de Grafana, ¿cómo la recupero?**

R: Reinicie el contenedor de Grafana para volver a las credenciales por defecto:

```bash
# Detener Grafana
docker compose -f connexionDB/docker-compose.yml down

# Eliminar datos de Grafana (¡perderá dashboards!)
rm -rf connexionDB/grafana-data/grafana.db

# Reiniciar Grafana
docker compose -f connexionDB/docker-compose.yml up -d

# Usar credenciales por defecto: admin/admin
```

---

**P: ¿Puedo acceder a Grafana desde otra computadora?**

R: Sí, desde otra computadora en la misma red:

```
http://[IP-DEL-SERVIDOR]:3000
```

Para encontrar la IP del servidor:

```bash
ip addr show | grep "inet "
```

---

**P: ¿Cómo exporto un dashboard?**

R: En Grafana:

1. Abra el dashboard
2. Haga clic en **⚙️ Dashboard settings**
3. Seleccione **JSON Model**
4. Copie el JSON
5. Guárdelo en un archivo `.json`

Para importar:

1. **[+]** → **Import**
2. Pegue el JSON
3. **Load**

---

### 8.4 Rendimiento

**P: El sistema está muy lento, ¿qué hago?**

R: Posibles causas y soluciones:

1. **Muchos contenedores:**

   ```bash
   docker ps -q | wc -l  # Ver cantidad
   docker stop $(docker ps -q | tail -20)  # Detener últimos 20
   ```

2. **Base de datos grande:**

   ```bash
   # Limpiar datos antiguos (>7 días)
   sqlite3 database/metrics.db "DELETE FROM system_metrics WHERE timestamp < datetime('now', '-7 days');"
   ```

3. **Memoria insuficiente:**
   - Cerrar aplicaciones innecesarias
   - Aumentar RAM del sistema
   - Reducir contenedores activos

---

**P: ¿Cuántos contenedores puede manejar el sistema?**

R: Depende de los recursos de su máquina:

- **4GB RAM:** Máximo 20-30 contenedores pequeños
- **8GB RAM:** Máximo 50-70 contenedores
- **16GB+ RAM:** 100+ contenedores

El sistema tiene configurado un límite de 50 por defecto.

---

## 9. Solución de Problemas

### 9.1 Problemas Comunes al Iniciar

#### Problema: "Permission denied" al cargar módulos

**Error:**

```
insmod: ERROR: could not insert module: Operation not permitted
```

**Solución:**

```bash
# Usar sudo
sudo insmod kernel_modules/metric_computer_module/computer_metric.ko

# O verificar Secure Boot (debe estar deshabilitado)
mokutil --sb-state
```

---

#### Problema: "No se encuentra el archivo /proc/sysinfo_so1_202300638"

**Causa:** El módulo no se cargó correctamente.

**Solución:**

```bash
# Verificar que el módulo está cargado
lsmod | grep computer_metric

# Si no aparece, cargarlo
sudo insmod kernel_modules/metric_computer_module/computer_metric.ko

# Ver mensajes de error
dmesg | tail -20
```

---

#### Problema: Grafana no inicia

**Error:**

```
Error response from daemon: driver failed programming external connectivity
```

**Solución:**

```bash
# El puerto 3000 ya está en uso
# Opción 1: Detener servicio que usa el puerto
sudo lsof -i :3000
sudo kill [PID]

# Opción 2: Cambiar puerto de Grafana (ver FAQ)
```

---

### 9.2 Problemas Durante la Ejecución

#### Problema: El daemon se detiene solo

**Síntomas:**

- `ps aux | grep main` no muestra nada
- Grafana no recibe datos nuevos

**Solución:**

```bash
# Ver logs para identificar el error
tail -50 logs/daemon.log

# Causas comunes:
# 1. Falta de permisos
sudo ./main

# 2. Módulos desconectados
sudo insmod kernel_modules/metric_computer_module/computer_metric.ko
sudo insmod kernel_modules/metric_process_module/process_metric.ko

# 3. Base de datos corrupta
rm database/metrics.db  # ¡Perderá datos!
./main
```

---

#### Problema: Contenedores no aparecen en Grafana

**Verificaciones:**

```bash
# 1. ¿Hay contenedores corriendo?
docker ps

# 2. ¿El daemon está leyendo correctamente?
cat /proc/continfo_so1_202300638

# 3. ¿Grafana está conectado a la BD?
# En Grafana: Configuration → Data Sources → Test
```

---

#### Problema: Sistema muy lento

**Diagnóstico:**

```bash
# Ver uso de recursos
top
htop  # Si está instalado

# Ver uso de disco
df -h

# Ver contenedores y su consumo
docker stats
```

**Soluciones:**

1. **Limpiar contenedores:**

   ```bash
   docker system prune -a --volumes -f
   ```

2. **Limpiar base de datos:**

   ```bash
   sqlite3 database/metrics.db "VACUUM;"
   ```

3. **Reducir frecuencia de monitoreo:**
   Editar `main.go` y cambiar:
   ```go
   ticker := time.NewTicker(10 * time.Second)  // De 5s a 10s
   ```

---

### 9.3 Errores de Compilación

#### Problema: "linux/module.h: No such file or directory"

**Solución:**

```bash
# Instalar headers del kernel
sudo apt install linux-headers-$(uname -r)

# Verificar instalación
ls /lib/modules/$(uname -r)/build
```

---

#### Problema: "go: cannot find main module"

**Solución:**

```bash
# Inicializar módulo Go
go mod init main
go mod tidy
```

---

### 9.4 Obtener Ayuda Adicional

Si ninguna de las soluciones anteriores funciona:

1. **Ver logs completos:**

   ```bash
   # Logs del daemon
   cat logs/daemon.log

   # Logs del kernel
   dmesg | grep -E "sysinfo|continfo"

   # Logs de Docker
   docker logs grafana_monitoring
   ```

2. **Recopilar información del sistema:**

   ```bash
   # Guardar información para reporte
   uname -a > /tmp/system_info.txt
   lsmod >> /tmp/system_info.txt
   docker ps -a >> /tmp/system_info.txt
   docker images >> /tmp/system_info.txt
   ```

3. **Reiniciar todo desde cero:**

   ```bash
   # Detener todo
   sudo pkill -f "main"
   sudo rmmod process_metric
   sudo rmmod computer_metric
   docker compose -f connexionDB/docker-compose.yml down

   # Limpiar y reiniciar
   rm -rf database/ logs/
   ./build.sh
   # Seguir pasos de "Inicio del Sistema"
   ```

---

## Apéndice A: Referencia Rápida de Comandos

### Iniciar el Sistema

```bash
# 1. Cargar módulos
sudo insmod kernel_modules/metric_computer_module/computer_metric.ko
sudo insmod kernel_modules/metric_process_module/process_metric.ko

# 2. Iniciar daemon
sudo nohup ./main > logs/daemon.log 2>&1 &

# 3. Verificar Grafana
docker ps | grep grafana
```

### Detener el Sistema

```bash
sudo pkill -f "main"
sudo rmmod process_metric computer_metric
docker compose -f connexionDB/docker-compose.yml down
```

### Monitoreo

```bash
# Ver logs
tail -f logs/daemon.log

# Ver contenedores
docker ps

# Ver uso de recursos
docker stats

# Ver módulos cargados
lsmod | grep metric
```

### Limpieza

```bash
# Contenedores
docker stop $(docker ps -aq)
docker rm $(docker ps -aq)

# Volúmenes
docker volume prune -f

# Imágenes
docker image prune -a -f

# Base de datos antigua
sqlite3 database/metrics.db "DELETE FROM system_metrics WHERE timestamp < datetime('now', '-7 days');"
```

---

## Apéndice B: Glosario de Términos

| Término               | Definición                                                     |
| --------------------- | -------------------------------------------------------------- |
| **Contenedor**        | Unidad aislada que ejecuta una aplicación con sus dependencias |
| **Daemon**            | Programa que se ejecuta en segundo plano                       |
| **Dashboard**         | Interfaz visual que muestra información en forma de gráficas   |
| **Docker**            | Plataforma para crear y ejecutar contenedores                  |
| **Grafana**           | Herramienta de visualización de datos                          |
| **Kernel**            | Núcleo del sistema operativo Linux                             |
| **Módulo del Kernel** | Código que extiende funcionalidad del kernel                   |
| **RAM**               | Memoria de acceso aleatorio (Random Access Memory)             |
| **CPU**               | Procesador (Central Processing Unit)                           |
| **/proc**             | Sistema de archivos virtual con información del kernel         |
| **SQLite**            | Base de datos liviana embebida                                 |

---

## Contacto y Soporte

**Autor:** Estudiante SOPES1  
**Carnet:** 202300638  
**Fecha:** Diciembre 2025  
**Versión:** 1.0

---

**¡Gracias por usar el Sistema de Monitoreo de Contenedores!**
