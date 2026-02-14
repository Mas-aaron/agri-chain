from __future__ import annotations

import json
import uuid
from typing import Dict, List, Optional

from fastapi import APIRouter, HTTPException
from pydantic import BaseModel

from agrichain.db.sqlite import connect, init_db, insert_ledger_event, utc_now_iso, fetch_ledger

router = APIRouter()


class ContractCreateRequest(BaseModel):
    crop: str = "Maize"
    quantity_kg: float
    unit_price: float
    currency: str = "UGX"
    farmer_name: str
    evidence_hash: Optional[str] = None


class ContractPurchaseRequest(BaseModel):
    buyer_name: str


class ContractDeliverRequest(BaseModel):
    actor: str
    ref: Optional[str] = None


class ContractResponse(BaseModel):
    id: str
    crop: str
    quantity_kg: float
    unit_price: float
    currency: str
    status: str
    farmer_name: str
    buyer_name: Optional[str] = None
    evidence_hash: Optional[str] = None
    created_at: str

    @property
    def total(self) -> float:
        return self.quantity_kg * self.unit_price


class LedgerEventResponse(BaseModel):
    id: str
    time: str
    action: str
    actor: str
    contract_id: str
    meta: Dict[str, str]


def _row_to_contract(row) -> ContractResponse:
    return ContractResponse(
        id=str(row["id"]),
        crop=str(row["crop"]),
        quantity_kg=float(row["quantity_kg"]),
        unit_price=float(row["unit_price"]),
        currency=str(row["currency"]),
        status=str(row["status"]),
        farmer_name=str(row["farmer_name"]),
        buyer_name=(str(row["buyer_name"]) if row["buyer_name"] is not None else None),
        evidence_hash=(str(row["evidence_hash"]) if row["evidence_hash"] is not None else None),
        created_at=str(row["created_at"]),
    )


@router.get("/contracts", response_model=List[ContractResponse])
async def list_contracts(status: Optional[str] = None):
    init_db()
    with connect() as conn:
        if status:
            rows = conn.execute(
                "SELECT * FROM contracts WHERE LOWER(status)=LOWER(?) ORDER BY created_at DESC",
                (status,),
            ).fetchall()
        else:
            rows = conn.execute("SELECT * FROM contracts ORDER BY created_at DESC").fetchall()
        return [_row_to_contract(r) for r in rows]


@router.post("/contracts", response_model=ContractResponse)
async def create_contract(payload: ContractCreateRequest):
    if payload.quantity_kg <= 0:
        raise HTTPException(status_code=400, detail="quantity_kg must be > 0")
    if payload.unit_price <= 0:
        raise HTTPException(status_code=400, detail="unit_price must be > 0")
    if not payload.farmer_name.strip():
        raise HTTPException(status_code=400, detail="farmer_name is required")

    contract_id = f"FH-{uuid.uuid4().hex[:12]}"
    now = utc_now_iso()

    init_db()
    with connect() as conn:
        conn.execute(
            """
            INSERT INTO contracts (
                id, crop, quantity_kg, unit_price, currency, status,
                farmer_name, buyer_name, evidence_hash, created_at, updated_at
            ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
            """,
            (
                contract_id,
                payload.crop,
                float(payload.quantity_kg),
                float(payload.unit_price),
                payload.currency,
                "LISTED",
                payload.farmer_name.strip(),
                None,
                payload.evidence_hash,
                now,
                now,
            ),
        )
        insert_ledger_event(
            conn,
            action="MINT_AND_LIST",
            actor=payload.farmer_name.strip(),
            contract_id=contract_id,
            meta={"crop": payload.crop, "currency": payload.currency},
        )
        row = conn.execute("SELECT * FROM contracts WHERE id=?", (contract_id,)).fetchone()
        if row is None:
            raise HTTPException(status_code=500, detail="Failed to create contract")
        return _row_to_contract(row)


@router.post("/contracts/{contract_id}/purchase", response_model=ContractResponse)
async def purchase_contract(contract_id: str, payload: ContractPurchaseRequest):
    if not payload.buyer_name.strip():
        raise HTTPException(status_code=400, detail="buyer_name is required")

    init_db()
    with connect() as conn:
        row = conn.execute("SELECT * FROM contracts WHERE id=?", (contract_id,)).fetchone()
        if row is None:
            raise HTTPException(status_code=404, detail="Contract not found")
        if str(row["status"]).upper() != "LISTED":
            raise HTTPException(status_code=400, detail=f"Contract not purchasable (status={row['status']})")

        now = utc_now_iso()
        conn.execute(
            "UPDATE contracts SET status=?, buyer_name=?, updated_at=? WHERE id=?",
            ("PURCHASED", payload.buyer_name.strip(), now, contract_id),
        )
        insert_ledger_event(
            conn,
            action="PURCHASE",
            actor=payload.buyer_name.strip(),
            contract_id=contract_id,
            meta={"status": "PURCHASED"},
        )
        updated = conn.execute("SELECT * FROM contracts WHERE id=?", (contract_id,)).fetchone()
        return _row_to_contract(updated)


@router.post("/contracts/{contract_id}/deliver", response_model=ContractResponse)
async def deliver_contract(contract_id: str, payload: ContractDeliverRequest):
    if not payload.actor.strip():
        raise HTTPException(status_code=400, detail="actor is required")

    init_db()
    with connect() as conn:
        row = conn.execute("SELECT * FROM contracts WHERE id=?", (contract_id,)).fetchone()
        if row is None:
            raise HTTPException(status_code=404, detail="Contract not found")
        if str(row["status"]).upper() != "PURCHASED":
            raise HTTPException(status_code=400, detail=f"Contract not deliverable (status={row['status']})")

        now = utc_now_iso()
        conn.execute(
            "UPDATE contracts SET status=?, updated_at=? WHERE id=?",
            ("DELIVERED", now, contract_id),
        )
        meta: Dict[str, str] = {"status": "DELIVERED"}
        if payload.ref:
            meta["ref"] = payload.ref
        insert_ledger_event(
            conn,
            action="DELIVERY_RECORDED",
            actor=payload.actor.strip(),
            contract_id=contract_id,
            meta=meta,
        )
        updated = conn.execute("SELECT * FROM contracts WHERE id=?", (contract_id,)).fetchone()
        return _row_to_contract(updated)


@router.get("/ledger", response_model=List[LedgerEventResponse])
async def list_ledger(contract_id: Optional[str] = None, limit: int = 100):
    rows = fetch_ledger(contract_id=contract_id, limit=limit)

    events: List[LedgerEventResponse] = []
    for r in rows:
        try:
            meta_obj = json.loads(str(r["meta_json"]))
            if not isinstance(meta_obj, dict):
                meta_obj = {}
            meta = {str(k): str(v) for k, v in meta_obj.items()}
        except Exception:
            meta = {}

        events.append(
            LedgerEventResponse(
                id=str(r["id"]),
                time=str(r["time"]),
                action=str(r["action"]),
                actor=str(r["actor"]),
                contract_id=str(r["contract_id"]),
                meta=meta,
            )
        )

    return events
