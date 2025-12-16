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
  "ok": true,
  "start_stop": { "id": 57, "nombre": "Av. Gobernadores" },
  "end_stop": { "id": 1, "nombre": "Alameda" },
  "instructions": [
    {
      "from_stop": { "id": 57, "nombre": "Av. Gobernadores" },
      "to_stop": { "id": 1, "nombre": "Alameda" },
      "bus": "Koox 01 Troncal Eje Principal"
    }
  ],
  "num_buses": 1,
  "start_distance_km": 0.13,
  "end_distance_km": 0.18
}
```

---

# ➕ Endpoint faltante: Rutas

Este endpoint **NO rompe nada** y usa directamente `rutas.json`.

## 🔹 GET /rutas

Devuelve **todas las rutas** disponibles.

```http
GET /rutas
```

### Respuesta

```json
{
  "ok": true,
  "body": [
    {
      "nombre": "Koox 01 Troncal Eje Principal",
      "paradas": [1, 2, 3, 4]
    }
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
  "ok": true,
  "nombre": "Koox 01 Troncal Eje Principal",
  "paradas": [
    { "id": 1, "nombre": "Alameda" },
    { "id": 2, "nombre": "Centro Histórico" }
  ]
}
```

---

## 🧠 Detalles técnicos importantes

* El algoritmo **A*** penaliza cambios de camión
* Las rutas se calculan por **paradas reales**
* El sistema es compatible con mapas (Leaflet, Mapbox)
* CORS habilitado para Flutter Web y apps