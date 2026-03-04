"""
Adzuna Jobs API Service — secure backend proxy.
Fetches real internship listings from India and normalises them
to our standard format so the Flutter client never sees the API key.
"""

import httpx
from typing import Optional
from app.config import settings

ADZUNA_BASE = "https://api.adzuna.com/v1/api/jobs/in/search"


async def search_adzuna(
    what: str = "internship",
    where: Optional[str] = None,
    page: int = 1,
    page_size: int = 20,
) -> dict:
    """
    Call the Adzuna API and return a normalised response dict.

    Returns:
        {
            "items": [ { "id", "title", "company_name", "description",
                         "location", "category", "redirect_url",
                         "is_adzuna": true } ],
            "total": int,
            "page": int,
            "page_size": int,
            "pages": int,
        }
    """
    params = {
        "app_id": settings.ADZUNA_APP_ID,
        "app_key": settings.ADZUNA_APP_KEY,
        "what": what,
        "results_per_page": page_size,
        "content-type": "application/json",
    }
    if where:
        params["where"] = where

    url = f"{ADZUNA_BASE}/{page}"

    async with httpx.AsyncClient(timeout=15.0) as client:
        resp = client.build_request("GET", url, params=params)
        r = await client.send(resp)
        r.raise_for_status()
        data = r.json()

    raw_items = data.get("results", [])
    total = data.get("count", len(raw_items))

    items = []
    for j in raw_items:
        items.append({
            "id": j.get("id", ""),
            "title": j.get("title", "Internship"),
            "company_name": j.get("company", {}).get("display_name", "Unknown Company"),
            "description": j.get("description", ""),
            "location": j.get("location", {}).get("display_name", "India"),
            "category": j.get("category", {}).get("label", ""),
            "redirect_url": j.get("redirect_url", ""),
            "created": j.get("created", ""),
            "mode": "remote",
            "is_adzuna": True,
        })

    import math
    pages = math.ceil(total / page_size) if total > 0 else 1

    return {
        "items": items,
        "total": total,
        "page": page,
        "page_size": page_size,
        "pages": pages,
    }
