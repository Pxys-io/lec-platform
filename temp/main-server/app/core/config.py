from pydantic_settings import BaseSettings, SettingsConfigDict
from typing import List


class Settings(BaseSettings):
    model_config = SettingsConfigDict(env_file=".env", env_file_encoding="utf-8")

    MAIN_SERVER_HOST: str = "0.0.0.0"
    MAIN_SERVER_PORT: int = 8000
    MAIN_SERVER_URL: str = "http://localhost:8000"
    MAIN_SERVER_DEBUG: bool = True

    DATABASE_URL: str = "sqlite:///./lec_main.db"

    JWT_SECRET_KEY: str
    JWT_ALGORITHM: str = "HS256"
    JWT_ACCESS_TOKEN_EXPIRE_MINUTES: int = 30
    JWT_REFRESH_TOKEN_EXPIRE_DAYS: int = 7

    VIDEO_SERVER_BASE_URL: str = "http://localhost:8001"
    VIDEO_SERVER_INTERNAL_TOKEN: str = "dev-internal-token"

    CORS_ORIGINS: str = "http://localhost:3000"

    @property
    def cors_origins_list(self) -> List[str]:
        return [origin.strip() for origin in self.CORS_ORIGINS.split(",")]


settings = Settings()
