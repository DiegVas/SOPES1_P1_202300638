package utils

import (
	"encoding/json"
	"fmt"
	"io"
	"os"
)

func Readproc(ruta string) (map[string]interface{}, error) {
	// Se abre el archivo
	file, err := os.Open(ruta)
	if err != nil {
		return nil, fmt.Errorf("error al abrir el archivo %s: %v", ruta, err)
	}
	defer file.Close()

	// Se lee todo el contenido del archivo
	contenido, err := io.ReadAll(file)
	if err != nil {
		return nil, fmt.Errorf("error al leer el archivo: %v", err)
	}

	// Se parsea el JSON a un map genérico
	var datos map[string]interface{}
	err = json.Unmarshal(contenido, &datos)
	if err != nil {
		return nil, fmt.Errorf("error al parsear JSON: %v", err)
	}

	return datos, nil
}
