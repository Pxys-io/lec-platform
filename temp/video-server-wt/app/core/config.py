from pydantic_settings import BaseSettings


class Settings(BaseSettings):
    DATABASE_URL: str = "sqlite:///./video_server.db"
    SECRET_KEY: str = "video-server-secret-key-change-in-production"
    ALGORITHM: str = "HS256"
    ACCESS_TOKEN_EXPIRE_MINUTES: int = 60

    VIDEO_STORAGE_PATH: str = "./storage/videos"
    VIDEO_STORAGE_TYPE: str = "local"

    R2_ACCOUNT_ID: str = ""
    R2_ACCESS_KEY_ID: str = ""
    R2_SECRET_ACCESS_KEY: str = ""
    R2_BUCKET: str = "lec-videos"

    S3_BUCKET: str = ""
    S3_REGION: str = "us-east-1"
    S3_ACCESS_KEY: str = ""
    S3_SECRET_KEY: str = ""

    WATERMARK_DURATION_SECONDS: int = 1
    WATERMARK_POSITION: str = "bottom-right"
    WATERMARK_OPACITY: float = 0.7

    VIDEO_SERVER_BASE_URL: str = "http://localhost:8001"
    MAIN_SERVER_URL: str = "http://localhost:8000"

    class Config:
        env_file = ".env"


settings = Settings()