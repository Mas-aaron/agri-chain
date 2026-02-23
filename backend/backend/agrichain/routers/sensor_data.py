"""
Sensor data router — stores raw IoT readings + GPS coordinates
from the ESP32 rover for field mapping and historical analysis.
"""
from __future__ import annotations

import uuid
from datetime import datetime, timezone
from typing import Optional, List

from fastapi import APIRouter, Query
from pydantic import BaseModel, Field

from agrichain.db.sqlite import connect

router = APIRouter(prefix="/sensor-data", tags=["iot"])


# ── Models ────────────────────────────────────────────────────
class SensorReading(BaseModel):
    """Single sensor/GPS reading from the ESP32 rover."""
    device_id: str = Field(default="rover-01", description="Device identifier")
    latitude: float
    longitude: float
    altitude: Optional[float] = 0.0
    speed: Optional[float] = 0.0
    course: Optional[float] = 0.0
    satellites: Optional[int] = 0
    hdop: Optional[float] = 99.0
    # Soil sensor fields (optional, for when NPK sensor is added)
    nitrogen: Optional[float] = None
    phosphorus: Optional[float] = None
    potassium: Optional[float] = None
    temperature: Optional[float] = None
    humidity: Optional[float] = None
    ph: Optional[float] = None
    conductivity: Optional[float] = None
    # Free-form label
    label: Optional[str] = None


class SensorReadingResponse(BaseModel):
    id: str
    device_id: str
    latitude: float
    longitude: float
    altitude: float
    satellites: int
    hdop: float
    nitrogen: Optional[float]
    phosphorus: Optional[float]
    potassium: Optional[float]
    temperature: Optional[float]
    humidity: Optional[float]
    ph: Optional[float]
    conductivity: Optional[float]
    label: Optional[str]
    created_at: str


# ── Init table ────────────────────────────────────────────────
def _init_sensor_table():
    with connect() as conn:
        conn.execute("""
            CREATE TABLE IF NOT EXISTS sensor_readings (
                id TEXT PRIMARY KEY,
                device_id TEXT NOT NULL,
                latitude REAL NOT NULL,
                longitude REAL NOT NULL,
                altitude REAL DEFAULT 0,
                speed REAL DEFAULT 0,
                course REAL DEFAULT 0,
                satellites INTEGER DEFAULT 0,
                hdop REAL DEFAULT 99,
                nitrogen REAL,
                phosphorus REAL,
                potassium REAL,
                temperature REAL,
                humidity REAL,
                ph REAL,
                conductivity REAL,
                label TEXT,
                created_at TEXT NOT NULL
            )
        """)


_init_sensor_table()


# ── Endpoints ─────────────────────────────────────────────────
@router.post("", status_code=201)
async def store_reading(reading: SensorReading):
    """Store a sensor + GPS reading from the rover."""
    reading_id = f"SR-{uuid.uuid4().hex[:10].upper()}"
    now = datetime.now(timezone.utc).isoformat()

    with connect() as conn:
        conn.execute("""
            INSERT INTO sensor_readings (
                id, device_id, latitude, longitude, altitude,
                speed, course, satellites, hdop,
                nitrogen, phosphorus, potassium,
                temperature, humidity, ph, conductivity,
                label, created_at
            ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
        """, (
            reading_id, reading.device_id,
            reading.latitude, reading.longitude, reading.altitude or 0,
            reading.speed or 0, reading.course or 0,
            reading.satellites or 0, reading.hdop or 99,
            reading.nitrogen, reading.phosphorus, reading.potassium,
            reading.temperature, reading.humidity, reading.ph,
            reading.conductivity,
            reading.label, now,
        ))

    return {
        "id": reading_id,
        "status": "stored",
        "latitude": reading.latitude,
        "longitude": reading.longitude,
        "created_at": now,
    }


@router.get("")
async def list_readings(
    device_id: Optional[str] = None,
    limit: int = Query(default=100, le=1000),
    since: Optional[str] = None,
):
    """List stored sensor readings, optionally filtered by device and time."""
    _init_sensor_table()

    with connect() as conn:
        query = "SELECT * FROM sensor_readings"
        params: list = []
        conditions: list = []

        if device_id:
            conditions.append("device_id = ?")
            params.append(device_id)
        if since:
            conditions.append("created_at >= ?")
            params.append(since)

        if conditions:
            query += " WHERE " + " AND ".join(conditions)
        query += " ORDER BY created_at DESC LIMIT ?"
        params.append(limit)

        rows = conn.execute(query, params).fetchall()

    return [dict(r) for r in rows]


@router.get("/map")
async def get_map_data(
    device_id: Optional[str] = None,
    limit: int = Query(default=500, le=5000),
):
    """
    Return GPS coordinates as GeoJSON for map visualization.
    Perfect for plotting the rover's path on a map.
    """
    _init_sensor_table()

    with connect() as conn:
        if device_id:
            rows = conn.execute(
                "SELECT * FROM sensor_readings WHERE device_id=? ORDER BY created_at ASC LIMIT ?",
                (device_id, limit),
            ).fetchall()
        else:
            rows = conn.execute(
                "SELECT * FROM sensor_readings ORDER BY created_at ASC LIMIT ?",
                (limit,),
            ).fetchall()

    features = []
    for r in rows:
        props = {
            "id": r["id"],
            "device_id": r["device_id"],
            "satellites": r["satellites"],
            "hdop": r["hdop"],
            "created_at": r["created_at"],
        }
        # Include sensor values if present
        for key in ("nitrogen", "phosphorus", "potassium", "temperature", "humidity", "ph"):
            if r[key] is not None:
                props[key] = r[key]

        features.append({
            "type": "Feature",
            "geometry": {
                "type": "Point",
                "coordinates": [r["longitude"], r["latitude"], r["altitude"] or 0],
            },
            "properties": props,
        })

    return {
        "type": "FeatureCollection",
        "features": features,
        "total": len(features),
    }


@router.get("/stats")
async def reading_stats(device_id: Optional[str] = None):
    """Quick stats: total readings, latest position, bounding box."""
    _init_sensor_table()

    with connect() as conn:
        where = "WHERE device_id = ?" if device_id else ""
        params = [device_id] if device_id else []

        row = conn.execute(f"""
            SELECT
                COUNT(*) as total,
                MIN(latitude) as min_lat, MAX(latitude) as max_lat,
                MIN(longitude) as min_lon, MAX(longitude) as max_lon,
                MAX(created_at) as last_reading
            FROM sensor_readings {where}
        """, params).fetchone()

        latest = conn.execute(f"""
            SELECT latitude, longitude, altitude, satellites, hdop, created_at
            FROM sensor_readings {where}
            ORDER BY created_at DESC LIMIT 1
        """, params).fetchone()

    return {
        "total_readings": row["total"] if row else 0,
        "bounding_box": {
            "min_lat": row["min_lat"],
            "max_lat": row["max_lat"],
            "min_lon": row["min_lon"],
            "max_lon": row["max_lon"],
        } if row and row["total"] > 0 else None,
        "last_reading": dict(latest) if latest else None,
    }
