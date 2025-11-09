# load_groceries.py
import os, csv, re, asyncio
from decimal import Decimal, InvalidOperation

from dotenv import load_dotenv
load_dotenv()  # uses .env -> DATABASE_URL and optionally GROCERY_CSV_PATH

from sqlalchemy import String, Integer, Float, DECIMAL, DateTime, func
from sqlalchemy.ext.asyncio import create_async_engine, AsyncSession
from sqlalchemy.orm import declarative_base, Mapped, mapped_column, sessionmaker

# ---- Config ----
DATABASE_URL = os.getenv("DATABASE_URL")
CSV_PATH = "./GroceryDataset.csv"

# ---- SQLAlchemy setup (standalone; does not depend on your app imports) ----
Base = declarative_base()
engine = create_async_engine(DATABASE_URL, future=True, pool_pre_ping=True)
SessionLocal = sessionmaker(engine, class_=AsyncSession, expire_on_commit=False)

class GroceryItem(Base):
    __tablename__ = "grocery_items"
    id: Mapped[int] = mapped_column(primary_key=True, autoincrement=True)
    title: Mapped[str] = mapped_column(String(255), index=True)
    sub_category: Mapped[str] = mapped_column(String(120), index=True)
    price: Mapped[Decimal] = mapped_column(DECIMAL(10, 2))
    rating_value: Mapped[float | None] = mapped_column(Float, nullable=True)
    rating_count: Mapped[int | None] = mapped_column(Integer, nullable=True)
    created_at: Mapped["DateTime"] = mapped_column(DateTime(timezone=True), server_default=func.now())

PRICE_RE = re.compile(r"([0-9]+(?:\.[0-9]{1,2})?)")
RVAL_RE  = re.compile(r"([0-9]+(?:\.[0-9])?)")          # e.g., "4.6"
RCNT_RE  = re.compile(r"([0-9,]+)\s+reviews", re.I)     # e.g., "200 reviews"

def parse_price(s: str | None) -> Decimal | None:
    s = (s or "").replace(",", "").strip()
    m = PRICE_RE.search(s)
    if not m: return None
    try:
        return Decimal(m.group(1))
    except InvalidOperation:
        return None

def parse_rating_value(s: str | None) -> float | None:
    s = (s or "").strip()
    m = RVAL_RE.search(s)
    return float(m.group(1)) if m else None

def parse_rating_count(s: str | None) -> int | None:
    s = (s or "").strip()
    m = RCNT_RE.search(s)
    if not m: return None
    return int(m.group(1).replace(",", ""))

async def init_db():
    async with engine.begin() as conn:
        await conn.run_sync(Base.metadata.create_all)

async def load_csv(session: AsyncSession, path: str, chunk_size: int = 1000):
    inserted = 0
    batch: list[dict] = []

    with open(path, "r", encoding="utf-8", newline="") as f:
        r = csv.DictReader(f)
        for row in r:
            title = (row.get("Title") or "").strip()
            if not title:
                continue
            sub = (row.get("Sub Category") or "").strip()
            price = parse_price(row.get(" Price "))
            rv = parse_rating_value(row.get("Rating"))
            rc = parse_rating_count(row.get("Rating"))

            batch.append({
                "title": title,
                "sub_category": sub,
                "price": price if price is not None else Decimal("0.00"),
                "rating_value": rv,
                "rating_count": rc,
            })

            if len(batch) >= chunk_size:
                await session.execute(
                    GroceryItem.__table__.insert(),
                    batch
                )
                inserted += len(batch)
                batch.clear()

        if batch:
            await session.execute(
                GroceryItem.__table__.insert(),
                batch
            )
            inserted += len(batch)

    await session.commit()
    return inserted

async def main():
    if not DATABASE_URL:
        raise RuntimeError("DATABASE_URL is not set in .env")
    if not os.path.exists(CSV_PATH):
        raise FileNotFoundError(f"CSV not found at {CSV_PATH}")

    await init_db()
    async with SessionLocal() as session:
        n = await load_csv(session, CSV_PATH)
        print(f"Inserted {n} rows into grocery_items.")

if __name__ == "__main__":
    asyncio.run(main())
