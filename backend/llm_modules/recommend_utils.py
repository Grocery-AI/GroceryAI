# recommend_utils.py
from sqlalchemy import select, or_
from db import GroceryItem

async def get_relevant_grocery_items(
    session, 
    product_name: str, 
    limit: int = 20
):
    """
    Multi-stage relevance matching for grocery catalog.
    
    Steps:
    1. Title token fuzzy match → strongest signal
    2. sub_category token fuzzy match → fallback
    3. Top-rated items → final fallback
    
    SQL stage: NO LIMIT (search full dataset for best match)
    Python stage: LIMIT output to top <limit> items for LLM efficiency.
    """

    # -----------------------------
    # 1. Token split for fuzzy match
    # -----------------------------
    tokens = [t.strip() for t in product_name.split() if t.strip()]
    if not tokens:
        tokens = [product_name]

    # -----------------------------------
    # 2. TITLE-BASED MATCH (best signal)
    # -----------------------------------
    title_conditions = [
        GroceryItem.title.ilike(f"%{tok}%") for tok in tokens
    ]

    q1 = await session.execute(
        select(GroceryItem)
        .where(or_(*title_conditions))
    )
    title_matches = q1.scalars().all()

    if title_matches:
        # Python layer limit
        return title_matches[:limit]

    # --------------------------------------------------
    # 3. SUB_CATEGORY MATCH (medium signal fallback)
    # --------------------------------------------------
    subcat_conditions = [
        GroceryItem.sub_category.ilike(f"%{tok}%") for tok in tokens
    ]

    q2 = await session.execute(
        select(GroceryItem)
        .where(or_(*subcat_conditions))
    )
    subcat_matches = q2.scalars().all()

    if subcat_matches:
        return subcat_matches[:limit]

    # --------------------------------------------------
    # 4. TOP-RATED FALLBACK (weak signal)
    # --------------------------------------------------
    q3 = await session.execute(
        select(GroceryItem)
        .order_by(GroceryItem.rating_value.desc())
    )
    top_rated = q3.scalars().all()

    return top_rated[:limit]
