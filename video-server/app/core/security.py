from fastapi import Depends, HTTPException, status
from fastapi.security import HTTPBearer, HTTPAuthorizationCredentials

from app.core.config import settings

_security = HTTPBearer(auto_error=False)


def require_internal_token(
    credentials: HTTPAuthorizationCredentials | None = Depends(_security),
) -> None:
    """Gate for the internal-only API. The main server presents
    `Authorization: Bearer <INTERNAL_AUTH_TOKEN>` on every call. When the
    token is unset (dev default) auth is disabled; production MUST set it."""
    expected = settings.INTERNAL_AUTH_TOKEN
    if not expected:
        return
    if credentials is None or credentials.credentials != expected:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Invalid internal token",
            headers={"WWW-Authenticate": "Bearer"},
        )