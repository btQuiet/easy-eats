from __future__ import annotations

from pydantic import BaseModel, Field, field_validator, model_validator


SLOTS = {"desayuno", "comida", "cena", "merienda"}


class Credentials(BaseModel):
    username: str = Field(min_length=3, max_length=40, pattern=r"^[a-zA-Z0-9_.-]+$")
    password: str = Field(min_length=6, max_length=128)


class WeeklySlot(BaseModel):
    weekday: int = Field(ge=0, le=6)
    slot: str

    @field_validator("slot")
    @classmethod
    def valid_slot(cls, value: str) -> str:
        if value not in SLOTS:
            raise ValueError("Comida desconocida")
        return value


class ProfileInput(BaseModel):
    plan: str = "free"
    diet: str = "omnivore"
    schedule: list[WeeklySlot] = Field(default_factory=list)
    allergens: list[str] = Field(default_factory=list)
    excluded_ingredients: list[str] = Field(default_factory=list)
    liked_ingredients: list[str] = Field(default_factory=list)
    disliked_ingredients: list[str] = Field(default_factory=list)
    address: str = Field(default="", max_length=240)

    @model_validator(mode="after")
    def valid_profile(self) -> "ProfileInput":
        if self.plan not in {"free", "pro"} or self.diet not in {"omnivore", "vegetarian", "vegan"}:
            raise ValueError("Plan o dieta inválidos")
        if not self.schedule or len({(x.weekday, x.slot) for x in self.schedule}) != len(self.schedule):
            raise ValueError("Selecciona al menos una comida semanal, sin duplicados")
        for values in (self.allergens, self.excluded_ingredients,
                       self.liked_ingredients, self.disliked_ingredients):
            if len(values) != len(set(values)):
                raise ValueError("No repitas alérgenos o ingredientes")
        if set(self.liked_ingredients) & set(self.disliked_ingredients):
            raise ValueError("Un ingrediente no puede gustar y disgustar a la vez")
        if self.plan == "pro" and not self.address.strip():
            raise ValueError("El plan Pro requiere una dirección de prueba")
        return self


class GenerateInput(BaseModel):
    month: str = Field(pattern=r"^\d{4}-(0[1-9]|1[0-2])$")


class ReplaceInput(BaseModel):
    recipe_code: str
    expected_version: int = Field(ge=1)


class FeedbackInput(BaseModel):
    item_id: int
    rating: int
    comment: str = Field(default="", max_length=500)

    @field_validator("rating")
    @classmethod
    def valid_rating(cls, value: int) -> int:
        if value not in {-1, 1}:
            raise ValueError("La valoración debe ser -1 o 1")
        return value
