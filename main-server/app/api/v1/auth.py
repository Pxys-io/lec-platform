import json
from datetime import datetime
from typing import Optional

from fastapi import APIRouter, Depends, HTTPException, status, Query, Header
from sqlmodel import Session, select, func

from app.core.database import get_db
from app.core.security import (
    verify_password,
    get_password_hash,
    create_access_token,
    create_refresh_token,
    decode_token,
    get_current_user_id,
    get_optional_current_user_id,
    get_token_type,
)
from app.models import User, UserProfile, UserRole, UserActivity, UserDevice
from app.schemas import (
    UserCreate,
    UserUpdate,
    UserResponse,
    LoginRequest,
    TokenResponse,
)


router = APIRouter(prefix="/auth", tags=["auth"])


@router.post("/login", response_model=TokenResponse)
def login(request: LoginRequest, db: Session = Depends(get_db)):
    user = db.exec(select(User).where(User.email == request.email)).first()
    if not user or not verify_password(request.password, user.password_hash):
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Incorrect email or password",
        )

    if user.banned_until and user.banned_until > datetime.utcnow():
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="User is banned",
        )

    # Device limit check
    if request.device_id:
        existing_device = db.exec(
            select(UserDevice).where(
                UserDevice.user_id == user.id,
                UserDevice.device_id == request.device_id,
            )
        ).first()

        if existing_device:
            existing_device.last_login = datetime.utcnow()
            db.add(existing_device)
        else:
            device_count = db.exec(
                select(func.count(UserDevice.id)).where(
                    UserDevice.user_id == user.id
                )
            ).first() or 0

            if device_count >= user.device_limit:
                raise HTTPException(
                    status_code=status.HTTP_429_TOO_MANY_REQUESTS,
                    detail=f"Device limit exceeded ({user.device_limit}). Contact an admin to reset your devices.",
                )

            device = UserDevice(
                user_id=user.id,
                device_id=request.device_id,
                device_type=request.device_type or "mobile",
            )
            db.add(device)

    user.last_login = datetime.utcnow()
    db.add(user)
    db.commit()

    activity = UserActivity(
        user_id=user.id, action="login", ip_address="unknown"
    )
    db.add(activity)
    db.commit()

    access_token = create_access_token({"sub": user.id})
    refresh_token = create_refresh_token({"sub": user.id})

    return TokenResponse(access_token=access_token, refresh_token=refresh_token)


@router.post("/logout")
def logout(
    user_id: str = Depends(get_current_user_id),
    db: Session = Depends(get_db),
):
    activity = UserActivity(user_id=user_id, action="logout")
    db.add(activity)
    db.commit()
    return {"message": "Logged out successfully"}


@router.post("/register", response_model=UserResponse)
def register(
    request: UserCreate,
    db: Session = Depends(get_db),
    current_user_id: Optional[str] = Depends(get_optional_current_user_id),
):
    existing_users_count = db.exec(select(func.count(User.id))).first()
    
    # Logic:
    # 1. First user ever can be any role (Bootstrap)
    # 2. If authenticated user is ADMIN/SUPER_ADMIN, they can create any role
    # 3. If unauthenticated or non-admin, they can only register as STUDENT
    
    role_to_set = request.role
    
    if existing_users_count > 0:
        is_admin = False
        if current_user_id:
            curr_user = db.get(User, current_user_id)
            if curr_user and curr_user.role in [UserRole.ADMIN, UserRole.SUPER_ADMIN]:
                is_admin = True
        
        if not is_admin:
            if request.role != UserRole.STUDENT:
                raise HTTPException(
                    status_code=status.HTTP_403_FORBIDDEN,
                    detail="Only administrators can create non-student accounts",
                )
            role_to_set = UserRole.STUDENT

    existing = db.exec(select(User).where(User.email == request.email)).first()
    if existing:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Email already registered",
        )

    user = User(
        email=request.email,
        password_hash=get_password_hash(request.password),
        phone=request.phone,
        role=role_to_set,
    )
    db.add(user)
    db.flush()

    profile = UserProfile(
        user_id=user.id,
        first_name=request.first_name,
        last_name=request.last_name,
    )
    db.add(profile)
    db.commit()
    db.refresh(user)

    return UserResponse(
        id=user.id,
        email=user.email,
        phone=user.phone,
        role=user.role.value,
        created_at=user.created_at,
        last_login=user.last_login,
        banned_until=user.banned_until,
        first_name=profile.first_name,
        last_name=profile.last_name,
    )


@router.post("/refresh", response_model=TokenResponse)
def refresh_token(
    refresh_token: str = Query(...),
    db: Session = Depends(get_db),
):
    payload = decode_token(refresh_token)
    if payload.get("type") != "refresh":
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Invalid token type",
        )

    user_id = payload.get("sub")
    user = db.get(User, user_id)
    if not user:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="User not found",
        )

    if user.banned_until and user.banned_until > datetime.utcnow():
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="User is banned",
        )

    access_token = create_access_token({"sub": user.id})
    new_refresh_token = create_refresh_token({"sub": user.id})

    return TokenResponse(access_token=access_token, refresh_token=new_refresh_token)


@router.get("/me", response_model=UserResponse)
def get_me(
    user_id: str = Depends(get_current_user_id),
    db: Session = Depends(get_db),
):
    user = db.get(User, user_id)
    if not user:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="User not found")

    profile = db.exec(select(UserProfile).where(UserProfile.user_id == user.id)).first()

    return UserResponse(
        id=user.id,
        email=user.email,
        phone=user.phone,
        role=user.role.value,
        created_at=user.created_at,
        last_login=user.last_login,
        banned_until=user.banned_until,
        first_name=profile.first_name if profile else "",
        last_name=profile.last_name if profile else "",
        avatar_url=profile.avatar_url if profile else None,
    )


@router.put("/me", response_model=UserResponse)
def update_me(
    request: UserUpdate,
    user_id: str = Depends(get_current_user_id),
    db: Session = Depends(get_db),
):
    user = db.get(User, user_id)
    if not user:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="User not found")

    if request.email:
        existing = db.exec(
            select(User).where(User.email == request.email).where(User.id != user.id)
        ).first()
        if existing:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="Email already in use",
            )
        user.email = request.email

    if request.phone:
        user.phone = request.phone

    db.add(user)
    db.flush()

    profile = db.exec(select(UserProfile).where(UserProfile.user_id == user.id)).first()
    if not profile:
        profile = UserProfile(user_id=user.id)
        db.add(profile)

    if request.first_name is not None:
        profile.first_name = request.first_name
    if request.last_name is not None:
        profile.last_name = request.last_name

    db.commit()
    db.refresh(user)
    db.refresh(profile)

    return UserResponse(
        id=user.id,
        email=user.email,
        phone=user.phone,
        role=user.role.value,
        created_at=user.created_at,
        last_login=user.last_login,
        banned_until=user.banned_until,
        first_name=profile.first_name,
        last_name=profile.last_name,
        avatar_url=profile.avatar_url,
    )


@router.put("/me/password")
def change_password(
    current_password: str = Query(...),
    new_password: str = Query(...),
    user_id: str = Depends(get_current_user_id),
    db: Session = Depends(get_db),
):
    user = db.get(User, user_id)
    if not user:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="User not found")

    if not verify_password(current_password, user.password_hash):
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Current password is incorrect",
        )

    user.password_hash = get_password_hash(new_password)
    db.add(user)
    db.commit()

    return {"message": "Password changed successfully"}