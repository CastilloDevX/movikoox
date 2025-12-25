# 🚌 MOVIKOOX – API de Rutas Inteligentes de Transporte Público

MOVIKOOX es una **API REST en Flask** diseñada para calcular rutas óptimas de transporte público urbano, combinando **caminatas y trayectos en camión**, priorizando **menos transbordos** y **rutas de tipo Eje** (Eje Principal, Eje Norte, etc.) para ofrecer trayectos **claros, realistas y eficientes**.

El sistema está pensado para integrarse fácilmente con aplicaciones móviles, web o sistemas de mapas.

---

## 📁 Estructura del Proyecto

```
MOVIKOOX/
│
├── api/
│   └── v1/
│       ├── __init__.py
│       ├── data.py        # Carga de datos y constantes globales
│       ├── utils.py       # Algoritmos y lógica principal
│       └── endpoints.py   # Endpoints de la API v1
│
├── db/
│   ├── paradas.json       # Información de paradas
│   └── rutas.json         # Información de rutas
│
├── app.py                 # Punto de entrada principal
├── last_app.py            # Versión anterior (backup)
├── requirements.txt
├── .gitignore
└── README.md
```

---

## ⚙️ Requisitos

* Python **3.9 o superior**
* pip
* Virtualenv (recomendado)

---

## 🚀 Instalación y Ejecución

### 1️⃣ Clonar el repositorio

```bash
git clone https://github.com/tu-usuario/movikoox.git
cd movikoox
```

### 2️⃣ Crear el entorno virtual

```bash
python -m venv venv
```

### 3️⃣ Activar el entorno virtual

**Linux / macOS**

```bash
source venv/bin/activate
```

**Windows**

```bash
venv\Scripts\activate
```

### 4️⃣ Instalar dependencias

```bash
pip install -r requirements.txt
```

### 5️⃣ Ejecutar el servidor

```bash
python app.py
```

El servidor se levantará en:

```
http://localhost:5000
```

---

## 🌐 Versionado de la API

Todos los endpoints están versionados bajo:

```
/api/v1
```

Esto permite evolucionar el sistema sin romper compatibilidad futura.

## 📍 Endpoints Disponibles

### 🔹 1. Obtener todas las paradas

```
GET /api/v1/paradas
```

**Descripción:**
Devuelve la lista completa de paradas registradas.

---

### 🔹 2. Obtener una parada por ID

```
GET /api/v1/paradas/<id>
```

**Descripción:**
Devuelve la información de una parada específica según su ID.

---

### 🔹 3. Obtener la parada más cercana

```
GET /api/v1/paradas/cercana?latitud=LAT&longitud=LON
```

**Descripción:**
Calcula la parada más cercana a una ubicación geográfica usando distancia Haversine.

**Respuesta:**

```json
{
  "ok": true,
  "body": { ... },
  "distance_km": 0.23
}
```

### 🔹 4. Obtener paradas por nombre de ruta

```
GET /api/v1/paradas/bus/<nombre>
```

**Descripción:**
Devuelve todas las paradas que pertenecen a una ruta de camión específica.
Soporta:

* Coincidencias parciales
* Coincidencias por número
* Acentos y variaciones de texto

Ejemplos:

```
/paradas/bus/Koox15
```
```
/paradas/bus/SanFrancisco
```

## ⭐ 5. Calcular instrucciones de viaje (ENDPOINT PRINCIPAL)

```
GET /api/v1/instrucciones?inicio=LAT,LON&destino=LAT,LON
```

### 📌 ¿Qué hace este endpoint?

Este endpoint calcula **la mejor ruta completa** desde un punto inicial hasta un destino final, devolviendo:

* Caminata inicial a la parada más cercana
* Tramos de camión organizados
* Caminata final al destino
* Distancias reales
* Tiempo estimado por tramo
* Resumen total del viaje

---

## 🧠 ¿Cómo funciona el algoritmo?

### 🔸 1. Paradas más cercanas

Se buscan las paradas más cercanas al inicio y al destino usando distancia geográfica.

---

### 🔸 2. Grafo de transporte

El sistema modela el transporte como un **grafo de estados**:

```
(parada_id, ruta)
```

Cada estado representa estar en una parada específica dentro de una ruta específica.

### 🔸 3. Algoritmo de búsqueda (Dijkstra modificado)

Se utiliza un algoritmo de costo mínimo que **prioriza**:

1. **Menor número de camiones**
2. **Rutas tipo Eje**
3. **Menor distancia total**

Esto se logra usando una función de costo ponderada.

### 🔸 4. Preferencia por camiones de Eje

Las rutas que contienen palabras como:

* `Eje`
* `Troncal`
* `Principal`

reciben **menor penalización**, haciendo que el algoritmo las prefiera automáticamente cuando son viables.

Esto refleja el comportamiento real del transporte urbano:
👉 *Los ejes suelen ser más rápidos, frecuentes y confiables.*

### 🔸 5. Segmentación clara del viaje

El resultado se divide en **segmentos entendibles**:

* 🚶 Caminatas
* 🚌 Tramos de camión
* 📍 Paradas origen y destino
* ⏱️ Tiempo estimado por tramo

## 📤 Ejemplo de respuesta del endpoint `/instrucciones`

```json
{
  "ok": true,
  "instructions": [
    {
      "type": "walk",
      "distance_km": 0.3,
      "minutes": 4.2
    },
    {
      "type": "bus",
      "bus": "Koox 01 Troncal Eje Principal",
      "stops_count": 4,
      "distance_km": 2.1,
      "minutes": 8.6
    }
  ],
  "summary": {
    "num_buses": 1,
    "bus_km": 2.1,
    "walk_km": 0.3,
    "total_minutes": 12.8
  }
}
```

### 🔹 6. Obtener las rutas de cada bus.

```
GET /api/v1/rutas
```

**Descripción:**
Devuelve todas las rutas de cada camión de forma secuencial, obtienes una lista de todos los KO'OX y en cada una tendras las paradas en un array

## ✅ ¿Por qué este algoritmo es ideal para el proyecto?

✔️ No depende de APIs externas
✔️ Escala bien con más rutas
✔️ Prioriza decisiones humanas reales
✔️ Evita rutas innecesarias
✔️ Produce instrucciones claras para el usuario final

Es una solución **robusta, extensible y realista** para transporte público urbano.

## 🔮 Futuras mejoras (roadmap)

* ⏰ ETA por hora del día
* 📄 Documentación OpenAPI / Swagger

## 👨‍💻 Autor

Proyecto desarrollado como sistema de rutas inteligentes para transporte público de Campeche.
> **Jose Manuel Castillo Queh**