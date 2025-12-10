# Documentación de Imágenes Docker - Sistema de Contenedores

## Descripción General

Este proyecto implementa un sistema de generación automática de contenedores Docker mediante un cronjob que se ejecuta cada minuto. El sistema genera aleatoriamente 10 contenedores de entre 10 imágenes diferentes profesionales organizadas en dos grupos:

- **5 imágenes de alto consumo de recursos**
- **5 imágenes de bajo consumo de recursos**

---

## Imágenes Docker Implementadas

### Grupo 1: Imágenes de Alto Consumo de Recursos

Estas imágenes consumen cantidades significativas de RAM y/o CPU:

#### 1. Elasticsearch 9.2.2

**Imagen:** `elasticsearch:9.2.2`

**Descripción:** Motor de búsqueda y análisis distribuido de código abierto

**Consumo de recursos:**

- **Tamaño en disco:** 2.19 GB
- **Tamaño comprimido:** 740 MB
- **RAM en ejecución:** 1-2 GB típicamente
- **CPU:** Alto durante indexación y búsquedas

**Casos de uso:**

- Búsqueda de texto completo
- Análisis de logs (ELK Stack)
- Búsqueda empresarial
- Analytics en tiempo real

**Configuración especial:**

```bash
docker run -d --name elasticsearch-test \
  -e discovery.type=single-node \
  -e xpack.security.enabled=false \
  elasticsearch:9.2.2
```

---

#### 2. MongoDB Latest

**Imagen:** `mongo:latest`

**Descripción:** Base de datos NoSQL orientada a documentos

**Consumo de recursos:**

- **Tamaño en disco:** 1.25 GB
- **Tamaño comprimido:** 326 MB
- **RAM en ejecución:** 500 MB - 1 GB
- **CPU:** Medio-Alto durante operaciones de lectura/escritura

**Casos de uso:**

- Almacenamiento de documentos JSON
- Aplicaciones web escalables
- Datos no estructurados o semi-estructurados
- Big Data

**Configuración especial:**

```bash
docker run -d --name mongo-test \
  -e MONGO_INITDB_ROOT_USERNAME=admin \
  -e MONGO_INITDB_ROOT_PASSWORD=password \
  mongo:latest
```

---

#### 3. GitLab MCP

**Imagen:** `mcp/gitlab:latest`

**Descripción:** Plataforma de gestión de repositorios Git y DevOps

**Consumo de recursos:**

- **Tamaño en disco:** 254 MB
- **Tamaño comprimido:** 61.2 MB
- **RAM en ejecución:** 150-300 MB
- **CPU:** Medio durante operaciones Git

**Casos de uso:**

- Control de versiones Git
- CI/CD pipelines
- Gestión de proyectos
- Code review

---

#### 4. RabbitMQ 4.1.6 Management Alpine

**Imagen:** `rabbitmq:4.1.6-management-alpine`

**Descripción:** Message broker AMQP con interfaz de gestión web

**Consumo de recursos:**

- **Tamaño en disco:** 311 MB
- **Tamaño comprimido:** 98.4 MB
- **RAM en ejecución:** 200-400 MB
- **CPU:** Medio durante procesamiento de mensajes

**Casos de uso:**

- Mensajería asíncrona entre microservicios
- Colas de tareas
- Event-driven architectures
- Sistemas distribuidos

**Configuración especial:**

```bash
docker run -d --name rabbitmq-test \
  -e RABBITMQ_DEFAULT_USER=admin \
  -e RABBITMQ_DEFAULT_PASS=password \
  -p 15672:15672 \
  rabbitmq:4.1.6-management-alpine
```

---

#### 5. Jupyter Base Notebook

**Imagen:** `jupyter/base-notebook:x86_64-ubuntu-22.04`

**Descripción:** Entorno interactivo para computación científica y data science

**Consumo de recursos:**

- **Tamaño en disco:** 1.48 GB
- **Tamaño comprimido:** 311 MB
- **RAM en ejecución:** 300-500 MB (variable según notebooks)
- **CPU:** Variable según operaciones ejecutadas

**Casos de uso:**

- Data Science
- Machine Learning
- Análisis de datos
- Visualización de datos
- Investigación científica

**Configuración especial:**

```bash
docker run -d --name jupyter-test \
  -e JUPYTER_ENABLE_LAB=yes \
  -p 8888:8888 \
  jupyter/base-notebook:x86_64-ubuntu-22.04
```

---

### Grupo 2: Imágenes de Bajo Consumo de Recursos

Estas imágenes están optimizadas para consumo mínimo de recursos:

#### 1. Nginx Trixie Perl

**Imagen:** `nginx:trixie-perl`

**Descripción:** Servidor web y proxy inverso de alto rendimiento

**Consumo de recursos:**

- **Tamaño en disco:** 298 MB
- **Tamaño comprimido:** 76.2 MB
- **RAM en ejecución:** 10-50 MB
- **CPU:** Bajo (muy eficiente en manejo de conexiones)

**Casos de uso:**

- Servidor web estático
- Proxy inverso
- Balanceador de carga
- API Gateway

---

#### 2. Istio Distroless

**Imagen:** `istio/distroless:latest`

**Descripción:** Imagen minimalista "distroless" para componentes de Istio service mesh

**Consumo de recursos:**

- **Tamaño en disco:** 6.43 MB ⭐ (extremadamente ligera)
- **Tamaño comprimido:** 635 KB
- **RAM en ejecución:** 5-15 MB
- **CPU:** Muy bajo

**Casos de uso:**

- Componentes de Istio
- Contenedores sidecar
- Service mesh
- Microservicios seguros

**Nota:** Segunda imagen más ligera del conjunto

---

#### 3. Alpine Linux Docker CLI

**Imagen:** `alpinelinux/docker-cli:latest-s390x`

**Descripción:** Cliente Docker sobre Alpine Linux ultra ligero

**Consumo de recursos:**

- **Tamaño en disco:** 227 MB
- **Tamaño comprimido:** 51.5 MB
- **RAM en ejecución:** 5-20 MB
- **CPU:** Muy bajo (solo CLI)

**Casos de uso:**

- Automatización Docker
- CI/CD pipelines
- Docker-in-Docker (DinD)
- Scripts de deployment

**Configuración especial:**

```bash
docker run -d --name alpine-docker \
  alpinelinux/docker-cli:latest-s390x \
  sleep infinity
```

---

#### 4. BusyBox Unstable uClibc

**Imagen:** `busybox:unstable-uclibc`

**Descripción:** Colección de utilidades Unix en la imagen más minimalista posible

**Consumo de recursos:**

- **Tamaño en disco:** 2.09 MB ⭐⭐⭐ (LA MÁS LIGERA)
- **Tamaño comprimido:** 762 KB
- **RAM en ejecución:** 1-5 MB
- **CPU:** Mínimo

**Casos de uso:**

- Contenedor de debugging
- Contenedores auxiliares
- Init containers en Kubernetes
- Scripts básicos de shell

**Nota:** ¡La imagen más pequeña de todo el conjunto!

**Configuración especial:**

```bash
docker run -d --name busybox-test \
  busybox:unstable-uclibc \
  sleep infinity
```

---

#### 5. Redis Alpine 3.22

**Imagen:** `redis:alpine3.22`

**Descripción:** Base de datos en memoria de alto rendimiento optimizada con Alpine

**Consumo de recursos:**

- **Tamaño en disco:** 131 MB
- **Tamaño comprimido:** 33.9 MB
- **RAM en ejecución:** 20-100 MB (depende del uso)
- **CPU:** Bajo (muy eficiente)

**Casos de uso:**

- Sistema de caché
- Gestión de sesiones
- Colas ligeras
- Pub/Sub messaging
- Rate limiting

---

## Comparativa de Recursos

### Imágenes de Alto Consumo

| Imagen        | Tamaño Disco | Comprimido | RAM Ejecución | CPU        | Uso Principal       |
| ------------- | ------------ | ---------- | ------------- | ---------- | ------------------- |
| Elasticsearch | 2.19 GB      | 740 MB     | 1-2 GB        | Alto       | Búsqueda/Analytics  |
| MongoDB       | 1.25 GB      | 326 MB     | 500MB-1GB     | Medio-Alto | Base de datos NoSQL |
| Jupyter       | 1.48 GB      | 311 MB     | 300-500 MB    | Variable   | Data Science        |
| RabbitMQ      | 311 MB       | 98.4 MB    | 200-400 MB    | Medio      | Message Broker      |
| GitLab MCP    | 254 MB       | 61.2 MB    | 150-300 MB    | Medio      | DevOps/Git          |

**Total promedio de alto consumo:** ~1 GB en disco, ~400 MB RAM en ejecución

---

### Imágenes de Bajo Consumo

| Imagen           | Tamaño Disco | Comprimido | RAM Ejecución | CPU      | Uso Principal |
| ---------------- | ------------ | ---------- | ------------- | -------- | ------------- |
| Nginx            | 298 MB       | 76.2 MB    | 10-50 MB      | Bajo     | Web Server    |
| Redis Alpine     | 131 MB       | 33.9 MB    | 20-100 MB     | Bajo     | Caché/DB      |
| Alpine Docker    | 227 MB       | 51.5 MB    | 5-20 MB       | Muy Bajo | Docker CLI    |
| Istio Distroless | 6.43 MB      | 635 KB     | 5-15 MB       | Muy Bajo | Service Mesh  |
| BusyBox          | 2.09 MB      | 762 KB     | 1-5 MB        | Mínimo   | Utilidades    |

**Total promedio de bajo consumo:** ~133 MB en disco, ~20 MB RAM en ejecución

---

## Scripts de Automatización

### generate_containers.sh

Script principal que genera 10 contenedores aleatorios de las 10 imágenes disponibles.

**Ubicación:** `/docker_images/generate_containers.sh`

**Funcionalidad:**

- Verifica que Docker esté disponible
- Valida que las 10 imágenes existan
- Genera 10 contenedores aleatorios (puede ser cualquier combinación)
- Aplica configuraciones especiales según la imagen
- Asigna nombres únicos con timestamp
- Registra todas las operaciones en log
- Muestra resumen de operaciones exitosas/fallidas

**Características especiales:**

- **Selección verdaderamente aleatoria** entre las 10 imágenes
- **Configuración automática** de variables de entorno necesarias
- **Manejo especial** para imágenes sin servicio (BusyBox, Alpine)
- **Logging detallado** en `/var/log/docker_containers/` o `~/docker_containers_logs/`
- **Nombres únicos** con formato: `{imagen}_{YYYYMMDD_HHMMSS}_{índice}`
- **Códigos de color** para mejor legibilidad

**Configuraciones aplicadas automáticamente:**

```bash
# Elasticsearch
-e discovery.type=single-node -e xpack.security.enabled=false

# MongoDB
-e MONGO_INITDB_ROOT_USERNAME=admin -e MONGO_INITDB_ROOT_PASSWORD=password

# RabbitMQ
-e RABBITMQ_DEFAULT_USER=admin -e RABBITMQ_DEFAULT_PASS=password

# Jupyter
-e JUPYTER_ENABLE_LAB=yes

# BusyBox / Alpine (contenedores sin servicio)
sleep infinity
```

**Uso manual:**

```bash
cd /home/spuma/Documentos/Programacion/GO/SOPES1_P1_202300638/docker_images
./generate_containers.sh
```

**Ejemplo de output:**

```
==========================================
  Generador de Contenedores Docker
==========================================

Verificando imágenes Docker...
Imágenes de Alto Consumo:
  ✓ elasticsearch:9.2.2
  ✓ mongo:latest
  ✓ mcp/gitlab:latest
  ✓ rabbitmq:4.1.6-management-alpine
  ✓ jupyter/base-notebook:x86_64-ubuntu-22.04

Imágenes de Bajo Consumo:
  ✓ nginx:trixie-perl
  ✓ istio/distroless:latest
  ✓ alpinelinux/docker-cli:latest-s390x
  ✓ busybox:unstable-uclibc
  ✓ redis:alpine3.22

Generando 10 contenedores aleatorios...

[1/10] Generando contenedor: mongo_20251207_143052_1
  ✓ Contenedor mongo_20251207_143052_1 creado exitosamente
[2/10] Generando contenedor: busybox_20251207_143053_2
  ✓ Contenedor busybox_20251207_143053_2 creado exitosamente
...

==========================================
  Resumen de Generación
==========================================
Contenedores creados: 10/10
```

---

### setup_docker_cronjob.go

Programa en Go para configurar el cronjob automáticamente.

**Ubicación:** `/cronjob/setup_docker_cronjob.go`

**Funcionalidad:**

- Configura automáticamente el crontab del usuario actual
- Establece ejecución cada minuto (`* * * * *`)
- Evita duplicados en crontab
- Redirige output a log específico
- Verifica la configuración al finalizar

**Uso:**

```bash
cd /home/spuma/Documentos/Programacion/GO/SOPES1_P1_202300638/cronjob
go run setup_docker_cronjob.go
```

**Output esperado:**

```
2025/12/07 14:30:00 Script /home/spuma/.../generate_containers.sh ahora es ejecutable
2025/12/07 14:30:00 Cronjob agregado: * * * * * /home/spuma/.../generate_containers.sh >> .../cronjob_docker.log 2>&1
2025/12/07 14:30:00 === Cronjobs Actuales ===
* * * * * /home/spuma/.../generate_containers.sh >> .../cronjob_docker.log 2>&1
=== Fin de Cronjobs ===
2025/12/07 14:30:00 Cronjob para generación de contenedores Docker configurado exitosamente!
```

---

## Configuración del Sistema

### Prerequisitos

1. **Docker instalado y funcionando:**

```bash
docker --version
docker ps
```

2. **Imágenes descargadas:**

Todas las imágenes necesarias deben estar descargadas:

```bash
# Imágenes de alto consumo
docker pull elasticsearch:9.2.2
docker pull mongo:latest
docker pull mcp/gitlab:latest
docker pull rabbitmq:4.1.6-management-alpine
docker pull jupyter/base-notebook:x86_64-ubuntu-22.04

# Imágenes de bajo consumo
docker pull nginx:trixie-perl
docker pull istio/distroless:latest
docker pull alpinelinux/docker-cli:latest-s390x
docker pull busybox:unstable-uclibc
docker pull redis:alpine3.22
```

3. **Go instalado** (para el script de configuración del cronjob):

```bash
go version
```

---

### Instalación Paso a Paso

#### Paso 1: Verificar las imágenes

```bash
docker images | grep -E "elasticsearch|mongo|gitlab|rabbitmq|jupyter|nginx|istio|alpinelinux|busybox|redis"
```

Deberías ver las 10 imágenes listadas.

#### Paso 2: Probar la generación manual (opcional pero recomendado)

```bash
cd /home/spuma/Documentos/Programacion/GO/SOPES1_P1_202300638/docker_images
./generate_containers.sh
```

Verifica que se crearon 10 contenedores:

```bash
docker ps
```

#### Paso 3: Limpiar los contenedores de prueba (opcional)

```bash
docker stop $(docker ps -aq)
docker rm $(docker ps -aq)
```

#### Paso 4: Configurar el cronjob

```bash
cd /home/spuma/Documentos/Programacion/GO/SOPES1_P1_202300638/cronjob
go run setup_docker_cronjob.go
```

#### Paso 5: Verificar el cronjob

```bash
crontab -l
```

Deberías ver:

```
* * * * * /home/spuma/Documentos/Programacion/GO/SOPES1_P1_202300638/docker_images/generate_containers.sh >> /home/spuma/Documentos/Programacion/GO/SOPES1_P1_202300638/docker_images/cronjob_docker.log 2>&1
```

#### Paso 6: Esperar y verificar

Espera 1-2 minutos y verifica:

```bash
# Ver contenedores activos
docker ps

# Contar contenedores
docker ps | wc -l

# Ver logs del cron
tail -f /home/spuma/Documentos/Programacion/GO/SOPES1_P1_202300638/docker_images/cronjob_docker.log
```

---

## Monitoreo del Sistema

### Ver contenedores activos

```bash
# Todos los contenedores
docker ps

# Solo mostrar nombres
docker ps --format "{{.Names}}"

# Contar contenedores por imagen
docker ps --format "{{.Image}}" | sort | uniq -c
```

### Monitorear recursos en tiempo real

```bash
# Todos los contenedores
docker stats

# Filtrar solo nuestros contenedores
docker stats --no-stream

# Ver uso de CPU y RAM ordenado
docker stats --no-stream --format "table {{.Name}}\t{{.CPUPerc}}\t{{.MemUsage}}" | sort -k2 -rh
```

### Ver logs

```bash
# Log del cronjob
tail -f /home/spuma/Documentos/Programacion/GO/SOPES1_P1_202300638/docker_images/cronjob_docker.log

# Log del script
tail -f ~/docker_containers_logs/container_generation.log

# Log de un contenedor específico
docker logs nombre_contenedor
```

### Análisis de distribución

Ver qué imágenes se están usando más:

```bash
docker ps --format "{{.Image}}" | sort | uniq -c | sort -rn
```

Ejemplo de output:

```
   3 elasticsearch:9.2.2
   2 busybox:unstable-uclibc
   2 redis:alpine3.22
   1 mongo:latest
   1 nginx:trixie-perl
   1 rabbitmq:4.1.6-management-alpine
```

---

## Mantenimiento

### Detener todos los contenedores

```bash
docker stop $(docker ps -aq)
```

### Eliminar todos los contenedores

```bash
docker rm $(docker ps -aq)
```

### Limpiar contenedores detenidos automáticamente

```bash
docker container prune -f
```

### Limpiar todo (contenedores, imágenes no usadas, volúmenes)

```bash
docker system prune -a --volumes
```

### Desactivar el cronjob temporalmente

```bash
crontab -e
# Comentar la línea agregando # al inicio
# * * * * * /home/spuma/.../generate_containers.sh ...
```

### Eliminar el cronjob completamente

```bash
crontab -r
```

### Reiniciar el cronjob

```bash
cd /home/spuma/Documentos/Programacion/GO/SOPES1_P1_202300638/cronjob
go run setup_docker_cronjob.go
```

---

## Arquitectura del Sistema

```
SOPES1_P1_202300638/
├── docker_images/
│   ├── generate_containers.sh      # Script principal de generación
│   ├── cronjob_docker.log          # Log del cron
│   └── README.md                   # Esta documentación
├── cronjob/
│   ├── setup_docker_cronjob.go    # Configurador de cronjob
│   ├── cronjob.go                  # Cronjob para métricas
│   ├── deademon.go                 # Daemon
│   └── script_cron.sh              # Script de métricas
└── Kernel_modules/
    ├── metric_computer_module/     # Módulo de métricas de sistema
    └── metric_process_module/      # Módulo de métricas de procesos
```

---

## Distribución Esperada

Con selección completamente aleatoria entre 10 imágenes y generando 10 contenedores por minuto:

**Probabilidad teórica:** Cada imagen tiene 10% de probabilidad en cada selección

**En 1 ejecución (10 contenedores):**

- Esperado: ~1 contenedor por imagen
- Rango típico: 0-3 contenedores por imagen

**En 10 minutos (100 contenedores):**

- Esperado: ~10 contenedores por imagen
- Distribución más uniforme

**En 1 hora (600 contenedores):**

- Esperado: ~60 contenedores por imagen
- Distribución muy uniforme

---

## Validación del Sistema

### Test 1: Verificar imágenes disponibles

```bash
docker images | grep -E "elasticsearch|mongo|gitlab|rabbitmq|jupyter|nginx|istio|alpinelinux|busybox|redis" | wc -l
```

**Resultado esperado:** 10

### Test 2: Verificar cronjob configurado

```bash
crontab -l | grep generate_containers
```

**Resultado esperado:** Debe mostrar la línea del cron

### Test 3: Ejecución manual exitosa

```bash
cd /home/spuma/Documentos/Programacion/GO/SOPES1_P1_202300638/docker_images
./generate_containers.sh
echo $?
```

**Resultado esperado:**

- 10 contenedores creados
- Exit code: 0

### Test 4: Verificar generación automática

```bash
# Esperar 2-3 minutos después de configurar el cron
docker ps | wc -l
```

**Resultado esperado:** Múltiplos de 10 + 1 (header)

- Ejemplo: 11, 21, 31, 41, etc.

---

## Análisis de Consumo

### Escenario 1: 10 contenedores (1 ejecución)

**Mejor caso (todas bajo consumo):**

- RAM total: ~50-200 MB
- CPU: <5%

**Peor caso (todas alto consumo):**

- RAM total: ~4-8 GB
- CPU: Variable (alto si hay Elasticsearch)

**Caso promedio (distribución aleatoria):**

- RAM total: ~2-3 GB
- CPU: 10-30%

### Escenario 2: 100 contenedores (10 minutos)

**Caso promedio:**

- RAM total: ~20-30 GB
- CPU: Moderado-Alto
- **⚠️ ADVERTENCIA:** Monitorear recursos del sistema

### Escenario 3: Ejecución continua (1 hora+)

**⚠️ PRECAUCIÓN:** Sin limpieza automática, el sistema puede:

- Quedarse sin RAM
- Degradar performance
- Llenar disco con logs

**Recomendación:** Implementar limpieza periódica

---

## Limpieza Automática (Recomendada)

Para evitar saturación del sistema, crea un segundo cronjob de limpieza:

```bash
# Agregar limpieza cada 10 minutos
(crontab -l 2>/dev/null; echo "*/10 * * * * docker container prune -f >> ~/docker_cleanup.log 2>&1") | crontab -
```

O crea un script de limpieza inteligente:

```bash
#!/bin/bash
# cleanup_old_containers.sh

# Detener y eliminar contenedores con más de 1 hora
docker ps -a --filter "name=elasticsearch\|mongo\|gitlab\|rabbitmq\|jupyter\|nginx\|istio\|alpinelinux\|busybox\|redis" \
  --format "{{.ID}} {{.CreatedAt}}" | \
  while read id created; do
    age=$(date -d "$created" +%s)
    now=$(date +%s)
    diff=$((now - age))

    # Si tiene más de 3600 segundos (1 hora)
    if [ $diff -gt 3600 ]; then
      echo "Eliminando contenedor antiguo: $id"
      docker rm -f $id
    fi
  done
```

---

## Troubleshooting

### Problema: Imágenes no encontradas

**Error:**

```
✗ Imagen elasticsearch:9.2.2 no encontrada
```

**Solución:**

```bash
docker pull elasticsearch:9.2.2
```

### Problema: El cronjob no se ejecuta

**Verificación 1:** ¿Está cron activo?

```bash
systemctl status cron
# o
systemctl status crond
```

**Verificación 2:** ¿Hay errores en syslog?

```bash
grep CRON /var/log/syslog | tail -20
```

**Verificación 3:** ¿El script es ejecutable?

```bash
ls -l /home/spuma/Documentos/Programacion/GO/SOPES1_P1_202300638/docker_images/generate_containers.sh
chmod +x /home/spuma/Documentos/Programacion/GO/SOPES1_P1_202300638/docker_images/generate_containers.sh
```

### Problema: Permisos de Docker

**Error:**

```
permission denied while trying to connect to the Docker daemon socket
```

**Solución:**

```bash
sudo usermod -aG docker $USER
newgrp docker
# O reiniciar sesión
```

### Problema: Sistema sin recursos

**Síntomas:**

- Contenedores fallan al iniciar
- Sistema lento
- Errores "cannot allocate memory"

**Solución inmediata:**

```bash
# Detener el cronjob
crontab -r

# Detener todos los contenedores
docker stop $(docker ps -aq)

# Limpiar
docker container prune -f
docker system prune -f
```

### Problema: Nombres de contenedor duplicados

**Error:**

```
Error response from daemon: Conflict. The container name "/..." is already in use
```

**Causa:** Poco probable debido a timestamps únicos, pero puede pasar si el sistema tiene problemas de tiempo

**Solución:**

```bash
docker rm -f nombre_contenedor_conflictivo
```

---

## Mejoras Futuras

### 1. Limpieza Automática Inteligente

- Implementar política de retención
- Mantener solo N contenedores más recientes
- Limpieza basada en uso de recursos

### 2. Métricas y Monitoreo

- Integrar con Prometheus
- Dashboards en Grafana
- Alertas de consumo

### 3. Balanceo de Carga

- Distribuir tipos de contenedores
- Evitar saturación con imágenes pesadas
- Algoritmos de selección más inteligentes

### 4. Logging Mejorado

- Rotación de logs
- Compresión de logs antiguos
- Integración con ELK stack

---

## Conclusión

Este sistema proporciona una solución completa y profesional para la generación automática de contenedores Docker con diferentes perfiles de consumo de recursos. Utiliza imágenes reales y ampliamente utilizadas en la industria, lo que lo hace ideal para:

- ✅ Pruebas de carga y stress testing
- ✅ Validación de sistemas de monitoreo
- ✅ Entrenamiento en gestión de contenedores
- ✅ Simulación de entornos de producción
- ✅ Testing de herramientas de orquestación

El sistema es configurable, escalable y completamente automatizado mediante cronjobs.

---

## Referencias

- [Docker Documentation](https://docs.docker.com/)
- [Elasticsearch](https://www.elastic.co/elasticsearch/)
- [MongoDB](https://www.mongodb.com/)
- [RabbitMQ](https://www.rabbitmq.com/)
- [Jupyter](https://jupyter.org/)
- [Nginx](https://nginx.org/)
- [Redis](https://redis.io/)
- [Istio](https://istio.io/)
- [Alpine Linux](https://alpinelinux.org/)
- [BusyBox](https://busybox.net/)
