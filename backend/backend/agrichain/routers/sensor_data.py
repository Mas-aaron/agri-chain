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

from agrichain.db.sqlite import connect, utc_now_iso

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
    # Multi-tenant fields
    session_id: Optional[str] = None
    farm_id: Optional[str] = None
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
    session_id: Optional[str]
    farm_id: Optional[str]
    label: Optional[str]
    created_at: str

class RoverSessionCreate(BaseModel):
    farm_id: str
    rover_id: str

class RoverSessionResponse(BaseModel):
    session_id: str
    farm_id: str
    rover_id: str
    started_at: str


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
                session_id TEXT REFERENCES rover_sessions(session_id),
                farm_id TEXT,
                label TEXT,
                created_at TEXT NOT NULL
            )
        """)
        # Auto-migrate: try adding new columns if they don't exist
        try:
            conn.execute("ALTER TABLE sensor_readings ADD COLUMN session_id TEXT REFERENCES rover_sessions(session_id)")
            conn.execute("ALTER TABLE sensor_readings ADD COLUMN farm_id TEXT")
        except Exception:
            pass  # Columns already exist


_init_sensor_table()


# ── Endpoints ─────────────────────────────────────────────────
@router.post("/sessions", status_code=201, response_model=RoverSessionResponse)
async def create_session(session: RoverSessionCreate):
    """Start a new data collection session for a specific farm."""
    session_id = str(uuid.uuid4())
    now = datetime.now(timezone.utc).isoformat()

    with connect() as conn:
        conn.execute(
            """
            INSERT INTO rover_sessions (session_id, farm_id, rover_id, started_at)
            VALUES (?, ?, ?, ?)
            """,
            (session_id, session.farm_id, session.rover_id, now)
        )
    
    return {
        "session_id": session_id,
        "farm_id": session.farm_id,
        "rover_id": session.rover_id,
        "started_at": now
    }


@router.post("", status_code=201)
async def store_reading(reading: SensorReading):
    """Store a sensor + GPS reading from the rover."""
    reading_id = f"SR-{uuid.uuid4().hex[:10].upper()}"
    now = datetime.now(timezone.utc).isoformat()

    with connect() as conn:
        # Auto-assign the active session if the rover didn't provide one
        if not reading.session_id:
            active_session = conn.execute(
                "SELECT session_id, farm_id FROM rover_sessions WHERE rover_id = ? ORDER BY started_at DESC LIMIT 1",
                (reading.device_id,)
            ).fetchone()
            if active_session:
                reading.session_id = active_session["session_id"]
                farm_id = active_session["farm_id"]

        # Determine the target farm based on the active session
        if reading.session_id and not farm_id:
            # Look up farm_id from the session
            row = conn.execute("SELECT farm_id FROM rover_sessions WHERE session_id = ?", (reading.session_id,)).fetchone()
            if row:
                farm_id = row["farm_id"]

        conn.execute("""
            INSERT INTO sensor_readings (
                id, device_id, latitude, longitude, altitude,
                speed, course, satellites, hdop,
                nitrogen, phosphorus, potassium,
                temperature, humidity, ph, conductivity,
                session_id, farm_id, label, created_at
            ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
        """, (
            reading_id, reading.device_id,
            reading.latitude, reading.longitude, reading.altitude or 0,
            reading.speed or 0, reading.course or 0,
            reading.satellites or 0, reading.hdop or 99,
            reading.nitrogen, reading.phosphorus, reading.potassium,
            reading.temperature, reading.humidity, reading.ph,
            reading.conductivity,
            reading.session_id, farm_id,
            reading.label, now,
        ))

    return {
        "id": reading_id,
        "status": "stored",
        "latitude": reading.latitude,
        "longitude": reading.longitude,
        "farm_id": farm_id,
        "session_id": reading.session_id,
        "created_at": now,
    }


@router.get("")
async def list_readings(
    device_id: Optional[str] = None,
    farm_id: Optional[str] = None,
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
        if farm_id:
            conditions.append("farm_id = ?")
            params.append(farm_id)
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
    farm_id: Optional[str] = None,
    limit: int = Query(default=500, le=5000),
):
    """
    Return GPS coordinates as GeoJSON for map visualization.
    Perfect for plotting the rover's path on a map.
    """
    _init_sensor_table()

    with connect() as conn:
        query = "SELECT * FROM sensor_readings"
        params: list = []
        conditions: list = []

        if device_id:
            conditions.append("device_id = ?")
            params.append(device_id)
        if farm_id:
            conditions.append("farm_id = ?")
            params.append(farm_id)

        if conditions:
            query += " WHERE " + " AND ".join(conditions)
        query += " ORDER BY created_at ASC LIMIT ?"
        params.append(limit)

        rows = conn.execute(query, params).fetchall()

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
async def reading_stats(
    device_id: Optional[str] = None,
    farm_id: Optional[str] = None
):
    """Quick stats: total readings, latest position, bounding box."""
    _init_sensor_table()

    with connect() as conn:
        conditions = []
        params = []
        if device_id:
            conditions.append("device_id = ?")
            params.append(device_id)
        if farm_id:
            conditions.append("farm_id = ?")
            params.append(farm_id)
            
        where = "WHERE " + " AND ".join(conditions) if conditions else ""

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
