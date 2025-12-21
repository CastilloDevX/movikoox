import json

# ------------------------------
# CONFIGURACIÓN GLOBAL
# ------------------------------
ROUND_DECIMALS = 8

PARADAS_JSON = "db/paradas.json"
RUTAS_JSON = "db/rutas.json"

WALK_KMH = 4.8
BUS_KMH = 18.0
DWELL_SECONDS_PER_STOP = 15


# ------------------------------
# CARGA DE DATOS
# ------------------------------
def load_json(path: str):
    with open(path, "r", encoding="utf-8") as f:
        return json.load(f)


try:
    stops_data = load_json(PARADAS_JSON)
except Exception as e:
    print("Error al cargar paradas:", e)
    stops_data = []

try:
    routes_data = load_json(RUTAS_JSON)
except Exception as e:
    print("Error al cargar rutas:", e)
    routes_data = []
