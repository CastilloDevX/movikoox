from flask import Flask, request, jsonify
from flask_cors import CORS
import json
import math
import heapq
from collections import defaultdict
import unicodedata
import re
from itertools import count

PARADAS_JSON = "db/paradas.json"
RUTAS_JSON = "db/rutas.json"

ROUND_DECIMALS = 8

app = Flask(__name__)
CORS(app)


# ---------------------------------------------------
# CARGA DE DATOS
# ---------------------------------------------------
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


# ---------------------------------------------------
# NORMALIZACIÓN Y DETECCIÓN DE EJES/TRONCALES
# ---------------------------------------------------
def normalize_text(text: str) -> str:
    text = (text or "").lower()
    text = unicodedata.normalize("NFD", text)
    text = "".join(c for c in text if unicodedata.category(c) != "Mn")
    text = re.sub(r"\s+", " ", text).strip()
    return text


def is_eje_route(route_name: str) -> bool:
    """
    Marca como 'eje' rutas que típicamente son troncales:
    - contiene 'troncal' o 'eje'
    - ejemplos: 'Troncal Eje Principal', 'Troncal Eje Norte', etc.
    """
    t = normalize_text(route_name)
    return ("troncal" in t) or ("eje" in t)


# ---------------------------------------------------
# DISTANCIA (KM)
# ---------------------------------------------------
def calculate_distance(lat1, lon1, lat2, lon2):
    R = 6371.0
    dlat = math.radians(lat2 - lat1)
    dlon = math.radians(lon2 - lon1)
    a = (math.sin(dlat / 2) ** 2) + math.cos(math.radians(lat1)) * math.cos(math.radians(lat2)) * (math.sin(dlon / 2) ** 2)
    c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a))
    return R * c


# ---------------------------------------------------
# MAPAS AUXILIARES + GRAFO REAL SECUENCIAL
# ---------------------------------------------------
stops_by_id = {int(s["id"]): s for s in stops_data}

# stop_id -> set(rutas)
stop_to_routes = defaultdict(set)

# grafo real: stop_id -> list[(neighbor_id, ruta_name)]
graph = defaultdict(list)

# Construcción del grafo usando rutas.json en orden
for ruta in routes_data:
    ruta_name = ruta.get("nombre", "")
    seq = [int(x) for x in ruta.get("paradas", [])]

    for sid in seq:
        stop_to_routes[sid].add(ruta_name)

    for a, b in zip(seq, seq[1:]):
        if a == b:
            continue
        graph[a].append((b, ruta_name))
        graph[b].append((a, ruta_name))


def distance_between_stops_km(a_id: int, b_id: int) -> float:
    a = stops_by_id.get(a_id)
    b = stops_by_id.get(b_id)
    if not a or not b:
        return 0.0
    return calculate_distance(a["latitud"], a["longitud"], b["latitud"], b["longitud"])


# ---------------------------------------------------
# PARADAS CERCANAS
# ---------------------------------------------------
def closest_stop(latitude, longitude):
    closest = None
    min_distance = float("inf")
    for stop in stops_data:
        d = calculate_distance(latitude, longitude, stop["latitud"], stop["longitud"])
        if d < min_distance:
            min_distance = d
            closest = stop
    return closest, min_distance


def stops_within_radius(latitude, longitude, radius_km):
    candidates = []
    for stop in stops_data:
        d = calculate_distance(latitude, longitude, stop["latitud"], stop["longitud"])
        if d <= radius_km:
            candidates.append((stop, d))
    candidates.sort(key=lambda x: x[1])
    return candidates


# ---------------------------------------------------
# RECONSTRUCCIÓN DE PATH
# ---------------------------------------------------
def reconstruct_path(came_from, goal_state):
    path = []
    current = goal_state
    while current in came_from:
        path.append(current)
        current = came_from[current]
    path.append(current)
    path.reverse()
    return path


# ---------------------------------------------------
# RUTA OPTIMA: MIN BUSES + PREFERIR EJES
# costo = (bus_count, non_eje_bus_count, bus_distance_km)
# estado = (stop_id, current_bus)
# ---------------------------------------------------
def route_min_buses_prefer_ejes(start_id: int, end_id: int):
    if start_id not in stops_by_id:
        return None

    pq = []
    came_from = {}
    best_cost = {}
    best_approx_state = None
    best_approx_dist = float("inf")

    tie = count()

    start_routes = stop_to_routes.get(start_id, set())
    if not start_routes:
        return None

    # Inicialización
    for bus in start_routes:
        non_eje = 0 if is_eje_route(bus) else 1
        state = (start_id, bus)
        cost = (1, non_eje, 0.0)
        best_cost[state] = cost
        heapq.heappush(pq, (cost, next(tie), state))

    while pq:
        (bus_count, non_eje_count, bus_dist), _, (cur_id, cur_bus) = heapq.heappop(pq)
        cur_state = (cur_id, cur_bus)

        if best_cost.get(cur_state, (10**9, 10**9, 10**9)) < (bus_count, non_eje_count, bus_dist):
            continue

        # evaluar qué tan cerca estamos del destino
        cur_stop = stops_by_id[cur_id]
        end_stop = stops_by_id[end_id]
        dist_to_dest = calculate_distance(
            cur_stop["latitud"], cur_stop["longitud"],
            end_stop["latitud"], end_stop["longitud"]
        )

        if dist_to_dest < best_approx_dist:
            best_approx_dist = dist_to_dest
            best_approx_state = cur_state

        # si llegamos exacto, regresamos
        if cur_id == end_id:
            return reconstruct_path(came_from, cur_state)

        # explorar vecinos
        for nxt_id, nxt_bus in graph.get(cur_id, []):
            add_bus = 1 if nxt_bus != cur_bus else 0
            nxt_bus_count = bus_count + add_bus

            add_non_eje = 0
            if add_bus == 1:
                add_non_eje = 0 if is_eje_route(nxt_bus) else 1

            step = distance_between_stops_km(cur_id, nxt_id)
            nxt_bus_dist = bus_dist + step

            nxt_state = (nxt_id, nxt_bus)
            nxt_cost = (nxt_bus_count, non_eje_count + add_non_eje, nxt_bus_dist)

            if nxt_cost < best_cost.get(nxt_state, (10**9, 10**9, 10**9)):
                best_cost[nxt_state] = nxt_cost
                came_from[nxt_state] = cur_state
                heapq.heappush(pq, (nxt_cost, next(tie), nxt_state))

    # SI NO SE LLEGÓ EXACTO → DEVOLVER MEJOR APROXIMACIÓN
    if best_approx_state:
        return reconstruct_path(came_from, best_approx_state)

    return None


# ---------------------------------------------------
# CONSTRUIR SEGMENTOS DE BUS (con dist + stops_count)
# ---------------------------------------------------
def build_bus_segments(path_states):
    if not path_states:
        return []

    segments = []
    current_bus = path_states[0][1]
    seg_start_id = path_states[0][0]
    seg_last_id = path_states[0][0]

    seg_distance = 0.0
    seg_stops_count = 1

    for (prev_id, prev_bus), (cur_id, cur_bus) in zip(path_states, path_states[1:]):
        edge_dist = distance_between_stops_km(prev_id, cur_id)

        if cur_bus != current_bus:
            segments.append({
                "bus": current_bus,
                "isEje": bool(is_eje_route(current_bus)),
                "from_stop": stops_by_id[seg_start_id],
                "to_stop": stops_by_id[seg_last_id],
                "distance_km": seg_distance,
                "stops_count": seg_stops_count
            })
            current_bus = cur_bus
            seg_start_id = prev_id
            seg_last_id = cur_id
            seg_distance = edge_dist
            seg_stops_count = 2
        else:
            seg_last_id = cur_id
            seg_distance += edge_dist
            seg_stops_count += 1

    segments.append({
        "bus": current_bus,
        "isEje": bool(is_eje_route(current_bus)),
        "from_stop": stops_by_id[seg_start_id],
        "to_stop": stops_by_id[seg_last_id],
        "distance_km": seg_distance,
        "stops_count": seg_stops_count
    })

    segments = [s for s in segments if s["bus"] is not None]
    return segments


# ---------------------------------------------------
# TIEMPOS ESTIMADOS
# ---------------------------------------------------
def minutes_from_km(distance_km: float, speed_kmh: float) -> float:
    if speed_kmh <= 0:
        return 0.0
    return (distance_km / speed_kmh) * 60.0


def estimate_bus_minutes(distance_km: float, stops_count: int, bus_kmh: float, dwell_seconds_per_stop: float) -> float:
    ride = minutes_from_km(distance_km, bus_kmh)
    dwell = (max(stops_count - 1, 0) * dwell_seconds_per_stop) / 60.0
    return ride + dwell


# ---------------------------------------------------
# ENDPOINTS BASE
# ---------------------------------------------------
@app.route("/paradas")
def get_paradas():
    return jsonify({"ok": True, "body": stops_data})


@app.route("/paradas/<int:id>")
def get_parada(id):
    stop = stops_by_id.get(id)
    if not stop:
        return jsonify({"ok": False, "message": "Parada no encontrada"}), 404
    return jsonify({"ok": True, "body": stop})


@app.route("/paradas/cercana")
def get_parada_cercana():
    try:
        latitude = float(request.args.get("latitud"))
        longitude = float(request.args.get("longitud"))
    except:
        return jsonify({"ok": False, "message": "Parámetros inválidos"}), 400

    stop, distance = closest_stop(latitude, longitude)
    if not stop:
        return jsonify({"ok": False, "message": "No se encontró parada"}), 404

    return jsonify({"ok": True, "body": stop, "distance_km": round(distance, ROUND_DECIMALS)})


@app.route("/paradas/bus/<name>")
def get_paradas_by_bus(name):
    def normalize(text: str) -> str:
        text = text.lower()
        text = unicodedata.normalize("NFD", text)
        text = "".join(c for c in text if unicodedata.category(c) != "Mn")
        text = re.sub(r"[^a-z0-9]", "", text)
        return text

    def extract_number(text: str):
        match = re.search(r"(\d+)", text)
        return int(match.group(1)) if match else None

    query_norm = normalize(name)
    query_number = extract_number(name)

    paradas = []
    for stop in stops_data:
        for ruta in stop.get("rutas", []):
            ruta_norm = normalize(ruta)
            ruta_number = extract_number(ruta)

            if query_number is not None and ruta_number == query_number:
                paradas.append(stop)
                break

            if query_norm in ruta_norm:
                paradas.append(stop)
                break

    if not paradas:
        return jsonify({"ok": False, "message": "No se encontraron paradas para este bus"}), 404

    return jsonify({"ok": True, "body": paradas})


# ---------------------------------------------------
# /INSTRUCCIONES
# Prioridad global para elegir mejor plan:
# 1) num_buses (mínimo)
# 2) non_eje_buses (mínimo)  <-- aquí se “prioriza ejes”
# 3) total_walk_km (mínimo)
# 4) bus_km (mínimo)
# ---------------------------------------------------
@app.route("/instrucciones")
def instrucciones():
    inicio_str = request.args.get("inicio")
    destino_str = request.args.get("destino")

    if not inicio_str or not destino_str:
        return jsonify({"ok": False, "message": "Parámetros requeridos"}), 400

    try:
        i_lat, i_lon = map(float, inicio_str.split(","))
        d_lat, d_lon = map(float, destino_str.split(","))
    except:
        return jsonify({"ok": False, "message": "Formato inválido"}), 400

    # Paradas reales más cercanas
    start_stop, start_walk = closest_stop(i_lat, i_lon)
    end_stop, end_walk = closest_stop(d_lat, d_lon)

    if not start_stop or not end_stop:
        return jsonify({"ok": False, "message": "No se encontraron paradas"}), 404

    # Ruta óptima priorizando:
    #    - menos camiones
    #    - menos NO-ejes
    path_states = route_min_buses_prefer_ejes(
        int(start_stop["id"]),
        int(end_stop["id"])
    )

    if not path_states:
        return jsonify({"ok": False, "message": "No hay ruta posible"}), 404

    # Construir segmentos
    bus_segments = build_bus_segments(path_states)

    instructions = []

    # caminar a la primera parada
    instructions.append({
        "type": "walk",
        "from": {"lat": i_lat, "lon": i_lon},
        "to_stop": start_stop,
        "distance_km": round(start_walk, ROUND_DECIMALS)
    })

    # tramos en camión
    for seg in bus_segments:
        instructions.append({
            "type": "bus",
            "bus": seg["bus"],
            "isEje": seg["isEje"],
            "from_stop": seg["from_stop"],
            "to_stop": seg["to_stop"],
            "stops_count": seg["stops_count"],
            "distance_km": round(seg["distance_km"], ROUND_DECIMALS)
        })

    # caminar al destino
    instructions.append({
        "type": "walk",
        "from_stop": end_stop,
        "to": {"lat": d_lat, "lon": d_lon},
        "distance_km": round(end_walk, ROUND_DECIMALS)
    })

    return jsonify({
        "ok": True,
        "isAprox": False,
        "start_stop": start_stop,
        "end_stop": end_stop,
        "instructions": instructions,
        "summary": {
            "num_buses": len(bus_segments),
            "eje_buses": sum(1 for s in bus_segments if s["isEje"]),
            "non_eje_buses": sum(1 for s in bus_segments if not s["isEje"]),
            "walk_km": round(start_walk + end_walk, ROUND_DECIMALS),
            "bus_km": round(sum(s["distance_km"] for s in bus_segments), ROUND_DECIMALS)
        }
    })

if __name__ == "__main__":
    app.run(host="localhost", port=5001)
