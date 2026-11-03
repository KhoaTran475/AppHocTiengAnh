from datetime import datetime
from typing import Optional, Dict
from pydantic import BaseModel, Field


class UserBase(BaseModel):
    username: str = Field(..., min_length=3, max_length=50)
    role: str = Field(default="learner", pattern="^(learner|admin)$")


class UserCreate(BaseModel):
    username: str = Field(..., min_length=3, max_length=50)
    password: str = Field(..., min_length=6)
    role: str = Field(default="learner", pattern="^(learner|admin)$")
    email: Optional[str] = None


class UserLogin(BaseModel):
    username: str
    password: str


class AdminLoginRequest(BaseModel):
    username: str
    password: str


class SendOTPRequest(BaseModel):
    email: str = Field(..., min_length=5, max_length=255)
    type: str = Field(default="register", pattern="^(register|login|reset_password)$")


class RegisterOTPVerifyRequest(BaseModel):
    email: str = Field(..., min_length=5, max_length=255)
    otp: str = Field(..., min_length=4, max_length=10)
    username: str = Field(..., min_length=3, max_length=50)
    password: str = Field(..., min_length=6)


class LoginOTPRequest(BaseModel):
    email: str = Field(..., min_length=5, max_length=255)
    otp: str = Field(..., min_length=4, max_length=10)


class OTPResponse(BaseModel):
    message: str
    expires_in_seconds: int


class UserResponse(BaseModel):
    id: int
    username: str
    role: str
    email: Optional[str] = None
    is_email_verified: bool = False
    supabase_uuid: Optional[str] = None
    is_face_auth_enabled: bool = False
    face_registered_at: Optional[datetime] = None
    created_at: datetime

    class Config:
        from_attributes = True


class Token(BaseModel):
    access_token: str
    token_type: str = "bearer"
    user: UserResponse


class TokenPayload(BaseModel):
    sub: Optional[str] = None
    role: Optional[str] = None
    exp: Optional[int] = None


class AdminKPISummary(BaseModel):
    total_users: int
    total_learners: int
    total_admins: int
    total_mappings: int
    total_notebook_items: int
    band_distribution: Dict[str, int]
