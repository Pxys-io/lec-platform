import os
import threading
from pathlib import Path
from typing import Optional

import boto3
import botocore
from botocore.client import Config

from app.core.config import settings

_client_lock = threading.Lock()
_client = None

_BUCKET_CORS_DONE = False
_CORS_LOCK = threading.Lock()


def get_r2_client():
    global _client
    with _client_lock:
        if _client is None:
            endpoint = f"https://{settings.R2_ACCOUNT_ID}.r2.cloudflarestorage.com"
            _client = boto3.client(
                "s3",
                endpoint_url=endpoint,
                region_name="auto",
                aws_access_key_id=settings.R2_ACCESS_KEY_ID,
                aws_secret_access_key=settings.R2_SECRET_ACCESS_KEY,
                config=Config(
                    signature_version="s3v4",
                    s3={"addressing_style": "path"},
                    retries={"max_attempts": 3},
                ),
            )
        return _client


def r2_enabled() -> bool:
    return (
        settings.VIDEO_STORAGE_TYPE == "r2"
        and bool(settings.R2_ACCOUNT_ID)
        and bool(settings.R2_ACCESS_KEY_ID)
        and bool(settings.R2_SECRET_ACCESS_KEY)
    )


def public_url(key: str) -> str:
    domain = settings.R2_PUBLIC_DOMAIN.rstrip("/")
    return f"{domain}/{key}"


# --- Key layout -------------------------------------------------------------

def original_key(video_id: str, ext: str) -> str:
    return f"originals/{video_id}{ext}"


def segment_key(video_id: str, resolution: str, filename: str) -> str:
    return f"videos/{video_id}/{resolution}/{filename}"


def video_prefix(video_id: str) -> str:
    return f"videos/{video_id}/"


def overlay_key(file_hash: str) -> str:
    return f"watermarks/overlays/{file_hash}.ts"


def break_screen_key(file_hash: str) -> str:
    return f"watermarks/break/{file_hash}.ts"


# --- Operations -------------------------------------------------------------

def object_exists(key: str) -> bool:
    if not r2_enabled():
        return False
    try:
        get_r2_client().head_object(Bucket=settings.R2_BUCKET, Key=key)
        return True
    except botocore.exceptions.ClientError as e:
        if e.response.get("ResponseMetadata", {}).get("HTTPStatusCode") == 404:
            return False
        raise
    except Exception:
        return False


def upload_file(key: str, local_path: str, content_type: Optional[str] = None):
    if not r2_enabled():
        raise RuntimeError("R2 storage not configured")
    extra = {"ContentType": content_type} if content_type else {}
    get_r2_client().upload_file(
        local_path, settings.R2_BUCKET, key, ExtraArgs=extra or None
    )


def upload_bytes(key: str, data: bytes, content_type: Optional[str] = None):
    if not r2_enabled():
        raise RuntimeError("R2 storage not configured")
    extra = {"ContentType": content_type} if content_type else {}
    get_r2_client().put_object(
        Bucket=settings.R2_BUCKET, Key=key, Body=data, **(extra or {})
    )


def download_file(key: str, dest_path: str):
    get_r2_client().download_file(settings.R2_BUCKET, key, dest_path)


def download_bytes(key: str) -> bytes:
    resp = get_r2_client().get_object(Bucket=settings.R2_BUCKET, Key=key)
    return resp["Body"].read()


def delete_object(key: str):
    try:
        get_r2_client().delete_object(Bucket=settings.R2_BUCKET, Key=key)
    except Exception:
        pass


def delete_prefix(prefix: str):
    if not r2_enabled():
        return
    try:
        paginator = get_r2_client().get_paginator("list_objects_v2")
        for page in paginator.paginate(Bucket=settings.R2_BUCKET, Prefix=prefix):
            keys = [o["Key"] for o in page.get("Contents", [])]
            if keys:
                get_r2_client().delete_objects(
                    Bucket=settings.R2_BUCKET,
                    Delete={"Objects": [{"Key": k} for k in keys]},
                )
    except Exception:
        pass


def localize(key: str, dest_dir: Path) -> Path:
    dest_dir.mkdir(parents=True, exist_ok=True)
    local_path = dest_dir / os.path.basename(key)
    if not local_path.exists() or local_path.stat().st_size == 0:
        download_file(key, str(local_path))
    return local_path


def ensure_bucket_cors():
    global _BUCKET_CORS_DONE
    with _CORS_LOCK:
        if _BUCKET_CORS_DONE:
            return
        _BUCKET_CORS_DONE = True
    if not r2_enabled():
        return
    try:
        get_r2_client().put_bucket_cors(
            Bucket=settings.R2_BUCKET,
            CORSConfiguration={
                "CORSRules": [
                    {
                        "AllowedOrigins": ["*"],
                        "AllowedMethods": ["GET", "HEAD"],
                        "AllowedHeaders": ["*"],
                        "ExposeHeaders": ["ETag", "Content-Length"],
                        "MaxAgeSeconds": 3600,
                    }
                ]
            },
        )
    except Exception as e:
        print(f"R2 CORS setup skipped: {e}")
