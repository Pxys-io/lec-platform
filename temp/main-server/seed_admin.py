import sys
import os

# Add the current directory to sys.path to import app
sys.path.append(os.getcwd())

from sqlmodel import Session, select
from app.core.database import engine, create_db_and_tables
from app.models.user import User, UserRole, UserProfile
from app.core.security import get_password_hash

def seed_admin():
    create_db_and_tables()
    
    with Session(engine) as session:
        # Check if admin already exists
        statement = select(User).where(User.email == "admin@lec.com")
        existing_admin = session.exec(statement).first()
        
        if existing_admin:
            print("Admin user already exists.")
            return

        # Create Super Admin
        admin_user = User(
            email="admin@lec.com",
            password_hash=get_password_hash("admin123"),
            phone="0000000000",
            role=UserRole.SUPER_ADMIN
        )
        session.add(admin_user)
        session.commit()
        session.refresh(admin_user)
        
        # Create profile
        profile = UserProfile(
            user_id=admin_user.id,
            first_name="Admin",
            last_name="User"
        )
        session.add(profile)
        session.commit()
        
        print(f"Super Admin created: {admin_user.email} (id: {admin_user.id})")

if __name__ == "__main__":
    seed_admin()
