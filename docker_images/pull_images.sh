#!/bin/bash

###############################################################################
# Script para descargar todas las imágenes Docker necesarias
#
# Este script descarga las 10 imágenes requeridas para el sistema:
# - 5 imágenes de alto consumo
# - 5 imágenes de bajo consumo
###############################################################################

# Colores
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${GREEN}=========================================="
echo -e "  Descarga de Imágenes Docker"
echo -e "==========================================${NC}"
echo

# Imágenes de alto consumo
echo -e "${YELLOW}Descargando imágenes de ALTO CONSUMO...${NC}"
echo

echo -e "${BLUE}[1/10] Elasticsearch 9.2.2...${NC}"
docker pull elasticsearch:9.2.2

echo -e "${BLUE}[2/10] MongoDB latest...${NC}"
docker pull mongo:latest

echo -e "${BLUE}[3/10] GitLab MCP latest...${NC}"
docker pull mcp/gitlab:latest

echo -e "${BLUE}[4/10] RabbitMQ 4.1.6 Management Alpine...${NC}"
docker pull rabbitmq:4.1.6-management-alpine

echo -e "${BLUE}[5/10] Jupyter Base Notebook...${NC}"
docker pull jupyter/base-notebook:x86_64-ubuntu-22.04

echo
echo -e "${YELLOW}Descargando imágenes de BAJO CONSUMO...${NC}"
echo

echo -e "${BLUE}[6/10] Nginx Trixie Perl...${NC}"
docker pull nginx:trixie-perl

echo -e "${BLUE}[7/10] Istio Distroless latest...${NC}"
docker pull istio/distroless:latest

echo -e "${BLUE}[8/10] Alpine Docker CLI...${NC}"
docker pull alpinelinux/docker-cli:latest-s390x

echo -e "${BLUE}[9/10] BusyBox Unstable uClibc...${NC}"
docker pull busybox:unstable-uclibc

echo -e "${BLUE}[10/10] Redis Alpine 3.22...${NC}"
docker pull redis:alpine3.22

echo
echo -e "${GREEN}=========================================="
echo -e "  Descarga Completada"
echo -e "==========================================${NC}"
echo
echo -e "${GREEN}Imágenes descargadas:${NC}"
docker images | grep -E "elasticsearch|mongo|gitlab|rabbitmq|jupyter|nginx|istio|alpinelinux|busybox|redis"

echo
echo -e "${YELLOW}Para verificar las imágenes:${NC}"
echo -e "  docker images"
echo
echo -e "${YELLOW}Para generar contenedores:${NC}"
echo -e "  ./generate_containers.sh"
