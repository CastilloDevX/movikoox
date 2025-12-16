# 🚌 KO'OX API – Transporte Público Campeche

API REST construida con **Flask** para consultar información del sistema de transporte **KO'OX Campeche**, incluyendo:

* 📍 Paradas
* 🚌 Rutas
* 📏 Parada más cercana
* 🧭 Instrucciones óptimas entre dos puntos (A* minimizando cambios de camión)

La API está pensada para usarse desde:

* Web
* Apps móviles
* Mapas interactivos

---

## 📦 Estructura del proyecto

```
/
├── main.py
└── db/
    ├── paradas.json
    └── rutas.json
```

---

## 🚀 Ejecutar la API

### 1. Instalar dependencias

```bash
pip install -r requirements.txt
```

### 2. Ejecutar

```bash
python main.py
```

La API quedará disponible en:

```
http://localhost:5000
```

---

## 📍 Endpoints disponibles

---

## 🔹 GET /paradas

Devuelve **todas las paradas KO'OX**.

### Ejemplo

```
GET http://localhost:5000/paradas
```

### Respuesta

```json
{
    "ok": true,
    "body": [
        {
            "id": 1,
            "latitud": 19.841517,
            "longitud": -90.534564,
            "nombre": "Alameda",
            "rutas": [
                "Koox 01 Troncal Eje Principal",
                "Ko'ox 13 Ampliación Concordia",
                "Koox 14 Kalá",
                "Koox 27 Troncal Eje Central",
                "Koox 29 Troncal Eje Norte"
            ]
        },
        {
            "id": 2,
            "latitud": 19.843134,
            "longitud": -90.530806,
            "nombre": "Chihuahua",
            "rutas": [
                "Koox 01 Troncal Eje Principal",
                "Ko'ox 13 Ampliación Concordia",
                "Koox 14 Kalá",
                "Koox 15 Jardines",
                "Koox 16 Polvorín - Paso de las águilas"
            ]
        },
        ... 568 más
    ]
}
```

---

## 🔹 GET /paradas/{id}

Obtiene una **parada específica** por su ID.

### Ejemplo

```
GET http://localhost:5000/paradas/1
```

### Respuesta

```json
{
    "ok": true,
    "body": {
        "id": 1,
        "latitud": 19.841517,
        "longitud": -90.534564,
        "nombre": "Alameda",
        "rutas": [
        "Koox 01 Troncal Eje Principal",
        "Ko'ox 13 Ampliación Concordia",
        "Koox 14 Kalá",
        "Koox 27 Troncal Eje Central",
        "Koox 29 Troncal Eje Norte"
        ]
    },
}
```

---

## 🔹 GET /paradas/bus/{nombre}

Devuelve todas las paradas por donde pasa un **camión específico**.

✔ No distingue mayúsculas
✔ Acepta búsquedas parciales

### Ejemplo

```
GET http://localhost:5000/paradas/bus/koox029
```

### Respuesta

```json
{
    "ok": true,
    "body": [
        {
            "id": 1,
            "latitud": 19.841517,
            "longitud": -90.534564,
            "nombre": "Alameda",
            "rutas": [
                "Koox 01 Troncal Eje Principal",
                "Ko'ox 13 Ampliación Concordia",
                "Koox 14 Kalá",
                "Koox 27 Troncal Eje Central",
                "Koox 29 Troncal Eje Norte"
            ]
        },
        {
            "id": 19,
            "latitud": 19.843275,
            "longitud": -90.531607,
            "nombre": "Circuito Baluartes",
            "rutas": [
                "Koox 01 Troncal Eje Principal",
                "Ko'ox 13 Ampliación Concordia",
                "Koox 14 Kalá",
                "Koox 15 Jardines",
                "Koox 16 Polvorín - Paso de las á1guilas",
                "Koox 18 San Francisco",
                "Koox 29 Troncal Eje Norte"
            ]
        },
    ]
}
```

---

## 🔹 GET /paradas/cercana

Devuelve la **parada más cercana** a una coordenada GPS.

### Parámetros

* `latitud`
* `longitud`

### Ejemplo

```
GET http://localhost:5000/paradas/cercana?latitud=19.791219&longitud=-90.619835
```

### Respuesta

```json
{
    "distance_km": 0.01046,
    "ok": true,
    "body": {
        "id": 441,
        "latitud": 19.791219,
        "longitud": -90.619935,
        "nombre": "Tec. De Lerma 2",
        "rutas": [
            "Koox 22 Lerma - Tec",
            "Koox 23 Kila - Marañón"
        ]
    }
}
```

---

## 🔹 GET /instrucciones

Calcula la **mejor ruta** entre dos puntos GPS usando **A***, minimizando:

* Cambios de camión
* Distancia total

### Parámetros

* `inicio=lat,lon`
* `destino=lat,lon`

### Ejemplo

```
GET http://localhost:5000/instrucciones?inicio=19.830211,-90.515757&destino=19.842192,-90.508463
```

### Respuesta

```json
{
    "isAprox": false,
    "ok": true,
    "summary": {
        "bus_km": 4.59060276,
        "eje_buses": 1,
        "eta_bus_minutes": 18.3,
        "eta_total_minutes": 24.61,
        "eta_transfer_minutes": 4.0,
        "eta_walk_minutes": 2.31,
        "non_eje_buses": 1,
        "num_buses": 2,
        "walk_km": 0.17713712
    },
    "instructions": [
        {
            "distance_km": 0.0,
            "eta_minutes": 0.0,
            "from": {
                "lat": 19.830211,
                "lon": -90.515757
            },
            "to_stop": {
                "id": 297,
                "latitud": 19.830211,
                "longitud": -90.515757,
                "nombre": "Nochebuena",
                "rutas": [
                    "Koox 15 Jardines"
                ]
            },
            "type": "walk"
        },

        {
            "bus": "Koox 15 Jardines",
            "distance_km": 2.40502248,
            "eta_minutes": 10.42,
            "from_stop": {
                "id": 297,
                "latitud": 19.830211,
                "longitud": -90.515757,
                "nombre": "Nochebuena",
                "rutas": [
                    "Koox 15 Jardines"
                ]
            },
            "isEje": false,
            "stops_count": 13,
            "to_stop": {
                "id": 18,
                "latitud": 19.843368,
                "longitud": -90.527729,
                "nombre": "Brasil",
                "rutas": [
                    "Koox 01 Troncal Eje Principal",
                    "Ko'ox 13 Ampliación Concordia",
                    "Koox 14 Kalá",
                    "Koox 15 Jardines",
                    "Koox 16 Polvorín - Paso de las Águilas"
                ]
            },
            "type": "bus"
        },
        {
            "eta_minutes": 4.0,
            "type": "transfer"
        },
        {
            "bus": "Koox 01 Troncal Eje Principal",
            "distance_km": 2.18558028,
            "eta_minutes": 7.89,
            "from_stop": {
                "id": 18,
                "latitud": 19.843368,
                "longitud": -90.527729,
                "nombre": "Brasil",
                "rutas": [
                    "Koox 01 Troncal Eje Principal",
                    "Ko'ox 13 Ampliación Concordia",
                    "Koox 14 Kalá",
                    "Koox 15 Jardines",
                    "Koox 16 Polvorín - Paso de las Águilas"
                ]
            },
            "isEje": true,
            "stops_count": 4,
            "to_stop": {
                "id": 138,
                "latitud": 19.842738,
                "longitud": -90.506872,
                "nombre": "Av. Aviación",
                "rutas": [
                    "Koox 01 Troncal Eje Principal",
                    "Koox 06 Amp. Bellavista - Revolución Circ. 1",
                    "Koox 08 Carmelo-Esperanza"
                ]
            },
            "type": "bus"
        },
        {
            "distance_km": 0.17713712,
            "eta_minutes": 2.31,
            "from_stop": {
                "id": 138,
                "latitud": 19.842738,
                "longitud": -90.506872,
                "nombre": "Av. Aviación",
                "rutas": [
                    "Koox 01 Troncal Eje Principal",
                    "Koox 06 Amp. Bellavista - Revolución Circ. 1",
                    "Koox 08 Carmelo-Esperanza"
                ]
            },
            "to": {
                "lat": 19.842192,
                "lon": -90.508463
            },
            "type": "walk"
        }
    ],
}
```

---

## 🔹 GET /rutas

Devuelve **todas las rutas** disponibles.

```http
GET http://localhost:5000/rutas
```

### Respuesta

```json
{
    "ok": true,
    "body": [
        {
            "nombre": "Koox 01 Troncal Eje Principal",
            "paradas": [1, 2, 3, 4] /* Id's */
        }

        ... 26 más
    ]
}
```

---

## 🔹 GET /rutas/{nombre}

Devuelve una **ruta específica** con **paradas completas y ordenadas**.

### Ejemplo

```
GET http://localhost:5000/rutas/koox01
```

### Respuesta

```json
{
    "nombre": "Koox 01 Troncal Eje Principal",
    "ok": true,
    "paradas": [
        {
            "id": 12,
            "latitud": 19.843619,
            "longitud": -90.503215,
            "nombre": "Álvaro Obregón",
            "rutas": [
                "Koox 01 Troncal Eje Principal",
                "Koox 07 Amp. Bellavista - Revolución Circ. 2",
                "Koox 08 Carmelo-Esperanza"
            ]
        },
        {
            "id": 10,
            "latitud": 19.842031,
            "longitud": -90.506114,
            "nombre": "La Huayita",
            "rutas": [
                "Koox 01 Troncal Eje Principal",
                "Koox 06 Amp. Bellavista - Revolución Circ. 1"
            ]
        },
        {
            "id": 138,
            "latitud": 19.842738,
            "longitud": -90.506872,
            "nombre": "Av. Aviación",
            "rutas": [
                "Koox 01 Troncal Eje Principal",
                "Koox 06 Amp. Bellavista - Revolución Circ. 1",
                "Koox 08 Carmelo-Esperanza"
            ]
        },
        ... más
    ]
}
```

---

## 🧠 Detalles técnicos importantes

* El algoritmo **A*** penaliza cambios de camión
* Las rutas se calculan por **paradas reales**
* El sistema es compatible con mapas (Leaflet, Mapbox)
* CORS habilitado para Flutter Web y apps