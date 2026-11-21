import uuid
from decimal import Decimal
from typing import Literal

from ninja import Schema
from pydantic import condecimal

SuggestionTarget = Literal["goal", "account"]


class SuggestIn(Schema):
    excess_funds: condecimal(max_digits=12, decimal_places=2)


# --- What the app receives ---------------------------------------------------


class SuggestionOut(Schema):
    """One suggested allocation. `id` is a goal id or an account id (see `type`),
    always one the requesting user owns; `name` is read from that record."""

    type: SuggestionTarget
    id: uuid.UUID
    name: str
    amount: Decimal
    reason: str


class SuggestOut(Schema):
    allocations: list[SuggestionOut]
    totalAllocated: Decimal
    reasoning: str


# --- What the model must reply with ------------------------------------------
#
# Model output is untrusted. It's validated against these before anything is
# stored or returned; ids are then checked against the user's own records.


class ModelSuggestion(Schema):
    type: SuggestionTarget
    id: str
    # No digit limit: models send floats like 33.333333333333336. Rounded to
    # cents when resolved.
    amount: condecimal(gt=0)
    reason: str = ""


class ModelReply(Schema):
    allocations: list[ModelSuggestion]
    reasoning: str
