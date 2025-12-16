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
# NORMALIZACIÓN
# ---------------------------------------------------
def normalize_text(text: str) -> str:
    text = (text or "").lower()
    text = unicodedata.normalize("NFD", text)
    text = "".join(c for c in text if unicodedata.category(c) != "Mn")
    text = re.sub(r"[^a-z0-9]", "", text)
    return text


def extract_number(text: str):
    m = re.search(r"(\d+)", text)
    return int(m.group(1)) if m else None


def is_eje_route(route_name: str) -> bool:
    t = normalize_text(route_name)
    return "troncal" in t or "eje" in t


# ---------------------------------------------------
# DISTANCIA
# ---------------------------------------------------
def calculate_distance(lat1, lon1, lat2, lon2):
    R = 6371.0
    dlat = math.radians(lat2 - lat1)
    dlon = math.radians(lon2 - lon1)
    a = math.sin(dlat / 2) ** 2 + math.cos(math.radians(lat1)) * math.cos(math.radians(lat2)) * math.sin(dlon / 2) ** 2
    c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a))
    return R * c


# ---------------------------------------------------
# MAPAS + GRAFO REAL
# ---------------------------------------------------
stops_by_id = {int(s["id"]): s for s in stops_data}
stop_to_routes = defaultdict(set)
graph = defaultdict(list)

for ruta in routes_data:
    nombre = ruta.get("nombre", "")
    seq = [int(x) for x in ruta.get("paradas", [])]

    for sid in seq:
        stop_to_routes[sid].add(nombre)

    for a, b in zip(seq, seq[1:]):
        if a != b:
            graph[a].append((b, nombre))
            graph[b].append((a, nombre))


def distance_between_stops_km(a, b):
    sa, sb = stops_by_id.get(a), stops_by_id.get(b)
    if not sa or not sb:
        return 0.0
    return calculate_distance(sa["latitud"], sa["longitud"], sb["latitud"], sb["longitud"])


# ---------------------------------------------------
# PARADAS CERCANAS
# ---------------------------------------------------
def closest_stop(lat, lon):
    best, best_d = None, float("inf")
    for s in stops_data:
        d = calculate_distance(lat, lon, s["latitud"], s["longitud"])
        if d < best_d:
            best, best_d = s, d
    return best, best_d


def stops_within_radius(lat, lon, radius_km):
    out = []
    for s in stops_data:
        d = calculate_distance(lat, lon, s["latitud"], s["longitud"])
        if d <= radius_km:
            out.append((s, d))
    out.sort(key=lambda x: x[1])
    return out


# ---------------------------------------------------
# A* = A Star
# ---------------------------------------------------
def route_min_buses_prefer_ejes(start_id, end_id):
    if start_id == end_id:
        return [(start_id, None)]

    start_routes = stop_to_routes.get(start_id, set())
    if not start_routes:
        return None

    pq, came_from, best_cost = [], {}, {}
    tie = count()

    for bus in start_routes:
        cost = (1, 0 if is_eje_route(bus) else 1, 0.0)
        state = (start_id, bus)
        best_cost[state] = cost
        heapq.heappush(pq, (cost, next(tie), state))

    while pq:
        (bc, ne, dist), _, (sid, bus) = heapq.heappop(pq)
        state = (sid, bus)

        if best_cost.get(state, (1e9, 1e9, 1e9)) < (bc, ne, dist):
            continue

        if sid == end_id:
            path = []
            while state in came_from:
                path.append(state)
                state = came_from[state]
            path.append(state)
            return list(reversed(path))

        for nid, nbus in graph.get(sid, []):
            add_bus = 1 if nbus != bus else 0
            cost2 = (
                bc + add_bus,
                ne + (0 if not add_bus or is_eje_route(nbus) else 1),
                dist + distance_between_stops_km(sid, nid),
            )
            nstate = (nid, nbus)
            if cost2 < best_cost.get(nstate, (1e9, 1e9, 1e9)):
                best_cost[nstate] = cost2
                came_from[nstate] = state
                heapq.heappush(pq, (cost2, next(tie), nstate))

    return None


# ---------------------------------------------------
# SEGMENTOS DE BUS
# ---------------------------------------------------
def build_bus_segments(path):
    if not path:
        return []

    segs = []
    bus = path[0][1]
    start = last = path[0][0]
    dist = 0.0
    stops = 1

    for (p_id, p_bus), (c_id, c_bus) in zip(path, path[1:]):
        d = distance_between_stops_km(p_id, c_id)
        if c_bus != bus:
            segs.append({
                "bus": bus,
                "isEje": is_eje_route(bus),
                "from_stop": stops_by_id[start],
                "to_stop": stops_by_id[last],
                "distance_km": dist,
                "stops_count": stops
            })
            bus = c_bus
            start, last, dist, stops = p_id, c_id, d, 2
        else:
            last, dist, stops = c_id, dist + d, stops + 1

    segs.append({
        "bus": bus,
        "isEje": is_eje_route(bus),
        "from_stop": stops_by_id[start],
        "to_stop": stops_by_id[last],
        "distance_km": dist,
        "stops_count": stops
    })

    return [s for s in segs if s["bus"]]


# ---------------------------------------------------
# ➕ ENDPOINTS DE RUTAS (NUEVO)
# ---------------------------------------------------
@app.route("/rutas")
def get_rutas():
    return jsonify({"ok": True, "body": routes_data})


@app.route("/rutas/<name>")
def get_ruta(name):
    q_norm = normalize_text(name)
    q_num = extract_number(name)

    match = None
    for r in routes_data:
        r_norm = normalize_text(r.get("nombre", ""))
        r_num = extract_number(r.get("nombre", ""))

        if q_num is not None and q_num == r_num:
            match = r
            break
        if q_norm in r_norm:
            match = r
            break

    if not match:
        return jsonify({"ok": False, "message": "Ruta no encontrada"}), 404

    paradas = []
    for pid in match.get("paradas", []):
        stop = stops_by_id.get(int(pid))
        if stop:
            paradas.append(stop)

    return jsonify({
        "ok": True,
        "nombre": match.get("nombre"),
        "paradas": paradas
    })


# ---------------------------------------------------
# ENDPOINTS EXISTENTES (SIN CAMBIOS)
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
    lat = float(request.args.get("latitud"))
    lon = float(request.args.get("longitud"))
    stop, dist = closest_stop(lat, lon)
    return jsonify({"ok": True, "body": stop, "distance_km": round(dist, ROUND_DECIMALS)})


if __name__ == "__main__":
    app.run(debug=True)
