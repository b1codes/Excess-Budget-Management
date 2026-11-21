import uuid
from datetime import datetime, timezone
from decimal import Decimal
from django.conf import settings
from apps.accounts.services import list_accounts
from apps.goals.services import list_goals, with_children
from apps.allocations.services import recent_allocation_summary
from apps.common.exceptions import UpstreamError
from apps.common.firestore import get_client
from apps.common.money import normalize, to_cents

COLLECTION = "allocation_suggestions"


def gather_context(user) -> dict:
    profile = getattr(user, "profile", None)
    ratio = float(profile.default_savings_ratio) if profile else 0.5

    goals = []
    for g in with_children(user, list_goals(user)):
        goals.append(
            {
                "id": str(g.id),
                "name": g.name,
                "category": g.category,
                "type": g.type,
                "target_amount": float(g.target_amount),
                "current_amount": float(g.current_amount),
                "target_date": g.target_date.isoformat() if g.target_date else None,
                "sub_goals": [
                    {
                        "name": s.name,
                        "target": float(s.target_amount),
                        "current": float(s.current_amount),
                    }
                    for s in g.sub_goals
                ],
            }
        )

    accounts = [
        {"id": str(a.id), "name": a.name, "balance": float(a.balance)} for a in list_accounts(user)
    ]

    return {
        "goals": goals,
        "accounts": accounts,
        "recentAllocations": recent_allocation_summary(user),
        "defaultSavingsRatio": ratio,
    }


def _build_prompt(excess: Decimal, ctx: dict) -> str:
    return (
        f"You are a financial advisor. The user has an excess budget of "
        f"${excess} this month. Prioritize short term goals and near target dates. "
        f"Recent 30-day allocations: ${ctx['recentAllocations']['totalSavings']} savings "
        f"and ${ctx['recentAllocations']['totalPurchases']} purchases. "
        f"Default ratio: {int(ctx['defaultSavingsRatio'] * 100)}% savings. "
        f"Goals: {ctx['goals']}. Accounts: {ctx['accounts']}. "
        f"Allocate at most ${excess} in total. "
        f"Reply as JSON with keys 'allocations' (list of {{type, id, amount, reason}}, where "
        f"type is 'goal' or 'account' and id is that goal's or account's id from above) "
        f"and 'reasoning' (string)."
    )


def call_gemini(prompt: str) -> dict:
    """Live call to Gemini. Mocked in tests."""
    import json
    from google import genai

    if not settings.GEMINI_API_KEY:
        raise UpstreamError("GEMINI_API_KEY is not configured.")
    try:
        client = genai.Client(api_key=settings.GEMINI_API_KEY)
        resp = client.models.generate_content(
            model="gemini-1.5-flash",
            contents=prompt,
            config={"response_mime_type": "application/json"},
        )
        return json.loads(resp.text)
    except Exception as e:
        raise UpstreamError(f"Gemini call failed: {e}") from e


def _resolve(excess: Decimal, reply, ctx: dict) -> dict:
    """Turn the model's reply into a SuggestOut payload.

    Model output is untrusted: a reply that doesn't match ModelReply, or that
    hands out more than the excess, is a 502 rather than a 500. Suggestions for
    ids the user doesn't own are dropped, so a made-up (or another user's) id
    never reaches the client. Names come from the user's records, not the model.
    """
    from pydantic import ValidationError
    from .schemas import ModelReply

    try:
        parsed = ModelReply.model_validate(reply)
    except ValidationError as e:
        raise UpstreamError(
            "Gemini returned a response in an unexpected format.",
            details={"errors": e.errors(include_url=False, include_input=False)},
        ) from e

    names = {
        "goal": {g["id"]: g["name"] for g in ctx["goals"]},
        "account": {a["id"]: a["name"] for a in ctx["accounts"]},
    }
    allocations = []
    for item in parsed.allocations:
        name = names[item.type].get(item.id)
        amount = normalize(item.amount)
        if name is None or amount <= 0:
            continue
        allocations.append(
            {
                "type": item.type,
                "id": item.id,
                "name": name,
                "amount": amount,
                "reason": item.reason,
            }
        )

    total = sum((a["amount"] for a in allocations), Decimal("0.00"))
    if total > excess:
        raise UpstreamError(
            "Gemini suggested allocating more than the excess funds.",
            details={"excess_funds": str(excess), "suggested": str(total)},
        )
    return {"allocations": allocations, "totalAllocated": total, "reasoning": parsed.reasoning}


def generate(user, excess: Decimal) -> dict:
    ctx = gather_context(user)
    prompt = _build_prompt(excess, ctx)
    reply = call_gemini(prompt)
    result = _resolve(excess, reply, ctx)

    suggestion_id = uuid.uuid4()
    get_client().collection(COLLECTION).document(str(suggestion_id)).set(
        {
            "user_id": str(user.id),
            "excess_funds": to_cents(excess),
            # The raw reply, for auditing what the model actually said.
            "response_json": reply,
            "created_at": datetime.now(timezone.utc),
        }
    )

    return result
