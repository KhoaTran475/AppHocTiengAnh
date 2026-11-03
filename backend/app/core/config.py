import os
from typing import List, Union
from pydantic import AnyHttpUrl, field_validator
from pydantic_settings import BaseSettings, SettingsConfigDict


class Settings(BaseSettings):
    PROJECT_NAME: str = "IELTS Vision Backend"
    VERSION: str = "1.0.0"
    API_V1_STR: str = "/api/v1"

    # Security & JWT
    SECRET_KEY: str = "ielts-vision-super-secret-key-change-in-production-2026"
    ALGORITHM: str = "HS256"
    ACCESS_TOKEN_EXPIRE_MINUTES: int = 60 * 24  # 24 hours

    # Supabase Configuration
    SUPABASE_URL: str = "https://tcbcmzfdidcwblvfmckb.supabase.co"
    SUPABASE_ANON_KEY: str = ""
    SUPABASE_SERVICE_ROLE_KEY: str = ""

    # Database
    DATABASE_URL: str = "sqlite:///./ielts_vision_backend.db"

    # SMTP Configuration (Gmail OTP)
    SMTP_HOST: str = "smtp.gmail.com"
    SMTP_PORT: int = 465
    SMTP_USER: str = ""
    SMTP_PASSWORD: str = ""
    SMTP_FROM_NAME: str = "IELTS Vision"
    OTP_EXPIRE_MINUTES: int = 5

    # Local Ollama AI Configuration (Vision & Vocabulary Qwen 2.5)
    OLLAMA_BASE_URL: str = "http://localhost:11434"
    OLLAMA_VISION_MODEL: str = "llava-phi3:latest"
    OLLAMA_VOCAB_MODEL: str = "qwen2.5:latest"
    OLLAMA_GRADING_MODEL: str = "qwen2.5:7b"
    AI_EXPLAIN_TIMEOUT_SECONDS: int = 40  # Dưới 60s để tránh proxy Nginx/ngrok timeout 504
    AI_WRITING_TIMEOUT_SECONDS: int = 60

    # CORS
    BACKEND_CORS_ORIGINS: Union[List[str], str] = ["*"]

    @field_validator("BACKEND_CORS_ORIGINS", mode="before")
    @classmethod
    def assemble_cors_origins(cls, v: Union[str, List[str]]) -> List[str]:
        if isinstance(v, str) and not v.startswith("["):
            return [i.strip() for i in v.split(",") if i.strip()]
        elif isinstance(v, list):
            return v
        return ["*"]

    model_config = SettingsConfigDict(
        env_file=os.path.join(os.path.dirname(os.path.dirname(os.path.dirname(__file__))), ".env"),
        env_file_encoding="utf-8",
        extra="ignore",
    )


settings = Settings()
