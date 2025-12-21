import math
import heapq
import unicodedata
import re
from collections import defaultdict
from itertools import count

from .data import stops_data, routes_data, WALK_KMH, BUS_KMH, DWELL_SECONDS_PER_STOP


# ---------------------------------------------------
# NORMALIZACIÓN
# ---------------------------------------------------
def normalize_text(text: str) -> str:
    text = (text or "").lower()
    text = unicodedata.normalize("NFD", text)
    text = "".join(c for c in text if unicodedata.category(c) != "Mn")
    text = re.sub(r"\s+", " ", text).strip()
    return text


def is_eje_route(route_name: str) -> bool:
    t = normalize_text(route_name)
    return ("troncal" in t) or ("eje" in t)


# ---------------------------------------------------
# DISTANCIA (KM)
# ---------------------------------------------------
def calculate_distance(lat1, lon1, lat2, lon2):
    R = 6371.0
    dlat = math.radians(lat2 - lat1)
    dlon = math.radians(lon2 - lon1)
    a = (
        math.sin(dlat / 2) ** 2 +
        math.cos(math.radians(lat1)) *
        math.cos(math.radians(lat2)) *
        math.sin(dlon / 2) ** 2
    )
    c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a))
    return R * c


# ---------------------------------------------------
# MAPAS Y GRAFO
# ---------------------------------------------------
stops_by_id = {int(s["id"]): s for s in stops_data}
stop_to_routes = defaultdict(set)
graph = defaultdict(list)

for ruta in routes_data:
    ruta_name = ruta.get("nombre", "")
    seq = [int(x) for x in ruta.get("paradas", [])]

    for sid in seq:
        stop_to_routes[sid].add(ruta_name)

    for a, b in zip(seq, seq[1:]):
        if a != b:
            graph[a].append((b, ruta_name))
            graph[b].append((a, ruta_name))


def distance_between_stops_km(a_id, b_id):
    a = stops_by_id.get(a_id)
    b = stops_by_id.get(b_id)
    if not a or not b:
        return 0.0
    return calculate_distance(
        a["latitud"], a["longitud"],
        b["latitud"], b["longitud"]
    )


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


# ---------------------------------------------------
# PATH
# ---------------------------------------------------
def reconstruct_path(came_from, goal_state):
    path = []
    cur = goal_state
    while cur in came_from:
        path.append(cur)
        cur = came_from[cur]
    path.append(cur)
    path.reverse()
    return path


# ---------------------------------------------------
# SEGMENTS
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
        step = distance_between_stops_km(prev_id, cur_id)

        if cur_bus != current_bus:
            segments.append({
                "bus": current_bus,
                "isEje": is_eje_route(current_bus),
                "from_stop": stops_by_id[seg_start_id],
                "to_stop": stops_by_id[seg_last_id],
                "distance_km": seg_distance,
                "stops_count": seg_stops_count
            })
            current_bus = cur_bus
            seg_start_id = prev_id
            seg_last_id = cur_id
            seg_distance = step
            seg_stops_count = 2
        else:
            seg_last_id = cur_id
            seg_distance += step
            seg_stops_count += 1

    segments.append({
        "bus": current_bus,
        "isEje": is_eje_route(current_bus),
        "from_stop": stops_by_id[seg_start_id],
        "to_stop": stops_by_id[seg_last_id],
        "distance_km": seg_distance,
        "stops_count": seg_stops_count
    })

    return segments


# ---------------------------------------------------
# RUTA ÓPTIMA A*
# ---------------------------------------------------
def route_min_buses_prefer_ejes(start_id, end_id):
    pq = []
    came_from = {}
    best_cost = {}
    best_approx_state = None
    best_approx_dist = float("inf")
    tie = count()

    for bus in stop_to_routes.get(start_id, []):
        non_eje = 0 if is_eje_route(bus) else 1
        state = (start_id, bus)
        cost = (1, non_eje, 0.0)
        best_cost[state] = cost
        heapq.heappush(pq, (cost, next(tie), state))

    while pq:
        (bus_c, non_eje_c, dist), _, (cur_id, cur_bus) = heapq.heappop(pq)

        cur_stop = stops_by_id[cur_id]
        end_stop = stops_by_id[end_id]

        d = calculate_distance(
            cur_stop["latitud"], cur_stop["longitud"],
            end_stop["latitud"], end_stop["longitud"]
        )

        if d < best_approx_dist:
            best_approx_dist = d
            best_approx_state = (cur_id, cur_bus)

        if cur_id == end_id:
            return reconstruct_path(came_from, (cur_id, cur_bus))

        for nxt_id, nxt_bus in graph.get(cur_id, []):
            add_bus = 1 if nxt_bus != cur_bus else 0
            add_non_eje = 0 if is_eje_route(nxt_bus) else 1 if add_bus else 0
            step = distance_between_stops_km(cur_id, nxt_id)

            nxt_state = (nxt_id, nxt_bus)
            nxt_cost = (
                bus_c + add_bus,
                non_eje_c + add_non_eje,
                dist + step
            )

            if nxt_cost < best_cost.get(nxt_state, (1e9, 1e9, 1e9)):
                best_cost[nxt_state] = nxt_cost
                came_from[nxt_state] = (cur_id, cur_bus)
                heapq.heappush(pq, (nxt_cost, next(tie), nxt_state))

    # CLAVE
    if best_approx_state:
        return reconstruct_path(came_from, best_approx_state)

    return None



# ---------------------------------------------------
# ESTIMATION
# ---------------------------------------------------
def minutes_from_km(distance_km, speed_kmh):
    if speed_kmh <= 0:
        return 0.0
    return (distance_km / speed_kmh) * 60.0

def estimate_bus_minutes(distance_km, stops_count):
    ride_minutes = minutes_from_km(distance_km, BUS_KMH)
    dwell_minutes = ((max(stops_count - 1, 0)) * DWELL_SECONDS_PER_STOP) / 60.0
    return ride_minutes + dwell_minutes

