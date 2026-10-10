"""Strict HTTP inputs used by the published OpenAPI schema."""
from typing import Any, Literal
from pydantic import BaseModel, ConfigDict, Field, StrictInt


class Input(BaseModel):
    model_config = ConfigDict(extra="forbid", strict=True)


class Credentials(Input):
    alias: str
    password: str = Field(min_length=8, max_length=128)
    transport: Literal["cookie", "bearer"] = "bearer"


class Versioned(Input):
    expected_version: StrictInt = Field(ge=0)


class Draft(Versioned):
    step: Literal["plan", "calendar", "restrictions", "preferences", "summary"]
    fields: dict[str, Any]


class ProfilePatch(Versioned):
    diet: Literal["omnivore", "vegetarian", "vegan"] | None = None
    allergen_codes: list[str] | None = None
    excluded_ingredient_codes: list[str] | None = None
    liked_ingredient_codes: list[str] | None = None
    disliked_ingredient_codes: list[str] | None = None
    preferred_categories: list[str] | None = None
    repetition_tolerance: Literal["low", "normal", "high"] | None = None


class CalendarUpdate(Versioned):
    weekly_slots: list[dict[str, Any]]


class AddressFields(Input):
    line1: str = Field(min_length=1, max_length=150)
    city: str = Field(min_length=1, max_length=80)
    postal_code: str = Field(min_length=1, max_length=12)
    notes: str = Field(default="", max_length=250)


class AddressUpdate(AddressFields, Versioned):
    pass


class PlanUpdate(Versioned):
    plan: Literal["free", "pro"]
    address: AddressFields | None = None
    expected_address_version: StrictInt | None = Field(default=None, ge=0)


class Ensure(Input):
    month: str = Field(pattern=r"^\d{4}-\d{2}$")


class Replacement(Versioned):
    recipe_code: str


class Opinion(Versioned):
    rating: StrictInt
    comment: str = Field(default="", max_length=500)
