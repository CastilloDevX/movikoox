from flask import Blueprint, request, jsonify
import unicodedata
import re

from .data import (
    ROUND_DECIMALS, 
    WALK_KMH, 
    BUS_KMH, 
    stops_data,
    routes_data,
)

from .utils import (
    stops_data, stops_by_id,
    closest_stop,
    route_min_buses_prefer_ejes,
    build_bus_segments,
    minutes_from_km,
    estimate_bus_minutes
)

api_v1 = Blueprint("api_v1", __name__)


@api_v1.route("/paradas")
def get_paradas():
    return jsonify({"ok": True, "body": stops_data})


@api_v1.route("/paradas/<int:id>")
def get_parada(id):
    stop = stops_by_id.get(id)
    if not stop:
        return jsonify({"ok": False, "message": "Parada no encontrada"}), 404
    return jsonify({"ok": True, "body": stop})


@api_v1.route("/paradas/cercana")
def get_parada_cercana():
    try:
        lat = float(request.args.get("latitud"))
        lon = float(request.args.get("longitud"))
    except:
        return jsonify({
            "ok": False,
            "message": "Parámetros inválidos"
        }), 400

    stop, distance = closest_stop(lat, lon)

    if not stop:
        return jsonify({
            "ok": False,
            "message": "No se encontró parada"
        }), 404

    return jsonify({
        "ok": True,
        "body": stop,
        "distance_km": round(distance, ROUND_DECIMALS)
    })


@api_v1.route("/instrucciones")
def instrucciones():
    inicio = request.args.get("inicio")
    destino = request.args.get("destino")

    if not inicio or not destino:
        return jsonify({"ok": False, "message": "Parámetros requeridos"}), 400

    i_lat, i_lon = map(float, inicio.split(","))
    d_lat, d_lon = map(float, destino.split(","))

    # paradas cercanas
    start_stop, start_walk = closest_stop(i_lat, i_lon)
    end_stop, end_walk = closest_stop(d_lat, d_lon)

    path_states = route_min_buses_prefer_ejes(
        int(start_stop["id"]),
        int(end_stop["id"])
    )

    if not path_states:
        return jsonify({"ok": False, "message": "No hay ruta"}), 404

    bus_segments = build_bus_segments(path_states)

    instructions = []

    # =========================
    # CAMINATA INICIAL
    # =========================
    walk_start_minutes = minutes_from_km(start_walk, WALK_KMH)

    instructions.append({
        "type": "walk",
        "from": {"lat": i_lat, "lon": i_lon},
        "to_stop": start_stop,
        "distance_km": round(start_walk, ROUND_DECIMALS),
        "minutes": round(walk_start_minutes, 2)
    })

    # =========================
    # TRAMOS DE BUS
    # =========================
    total_bus_minutes = 0.0

    for seg in bus_segments:
        bus_minutes = estimate_bus_minutes(
            seg["distance_km"],
            seg["stops_count"]
        )
        total_bus_minutes += bus_minutes

        instructions.append({
            "type": "bus",
            "bus": seg["bus"],
            "isEje": seg["isEje"],
            "from_stop": seg["from_stop"],
            "to_stop": seg["to_stop"],
            "stops_count": seg["stops_count"],
            "distance_km": round(seg["distance_km"], ROUND_DECIMALS),
            "minutes": round(bus_minutes, 2)
        })

    # =========================
    # 🚶‍♂️ CAMINATA FINAL
    # =========================
    walk_end_minutes = minutes_from_km(end_walk, WALK_KMH)

    instructions.append({
        "type": "walk",
        "from_stop": end_stop,
        "to": {"lat": d_lat, "lon": d_lon},
        "distance_km": round(end_walk, ROUND_DECIMALS),
        "minutes": round(walk_end_minutes, 2)
    })

    # =========================
    # RESUMEN DE TIEMPOS
    # =========================
    total_minutes = walk_start_minutes + total_bus_minutes + walk_end_minutes

    return jsonify({
        "ok": True,
        "isAprox": False,
        "instructions": instructions,
        "summary": {
            "num_buses": len(bus_segments),
            "eje_buses": sum(1 for s in bus_segments if s["isEje"]),
            "non_eje_buses": sum(1 for s in bus_segments if not s["isEje"]),
            "walk_km": round(start_walk + end_walk, ROUND_DECIMALS),
            "bus_km": round(sum(s["distance_km"] for s in bus_segments), ROUND_DECIMALS),
            "walk_minutes": round(walk_start_minutes + walk_end_minutes, 2),
            "bus_minutes": round(total_bus_minutes, 2),
            "total_minutes": round(total_minutes, 2)
        }
    })

@api_v1.route("/rutas")
def get_rutas():
    rutas_response = []

    for ruta in routes_data:
        paradas_full = []

        for stop_id in ruta.get("paradas", []):
            stop = stops_by_id.get(int(stop_id))
            if stop:
                paradas_full.append(stop)

        rutas_response.append({
            "nombre": ruta.get("nombre"),
            "paradas": paradas_full
        })

    return jsonify({
        "ok": True,
        "body": rutas_response
    })


@api_v1.route("/paradas/bus/<name>")
def get_paradas_by_bus(name):

    def normalize(text: str) -> str:
        text = text.lower()
        text = unicodedata.normalize("NFD", text)
        text = "".join(
            c for c in text
            if unicodedata.category(c) != "Mn"
        )
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
        return jsonify({
            "ok": False,
            "message": "No se encontraron paradas para este bus"
        }), 404

    return jsonify({
        "ok": True,
        "body": paradas
    })