import uuid
from dataclasses import dataclass, field
from datetime import date, datetime
from decimal import Decimal


@dataclass
class Goal:
    id: uuid.UUID
    user_id: str
    name: str
    target_amount: Decimal
    current_amount: Decimal
    target_date: date | None
    type: str
    category: str
    created_at: datetime
    # Filled in by services.with_children(); empty until then.
    sub_goals: list["Subgoal"] = field(default_factory=list)
    account_ids: list[uuid.UUID] = field(default_factory=list)


@dataclass
class Subgoal:
    id: uuid.UUID
    goal_id: uuid.UUID
    user_id: str
    name: str
    target_amount: Decimal
    current_amount: Decimal
    created_at: datetime


@dataclass
class GoalAccount:
    goal_id: uuid.UUID
    account_id: uuid.UUID
    user_id: str
    created_at: datetime
