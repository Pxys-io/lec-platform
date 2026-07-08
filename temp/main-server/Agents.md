# Main Server - Architecture Specification

## ⚠️ IMPORTANT: DO NOT CHANGE ANY MODEL OR ROUTE OR NAME
This document defines the core architecture for the Main Server. All models, API routes, and component names are fixed. Any modifications must be discussed and approved by the lead architect.

---

## Overview
Main Server handles authentication, authorization, content management, user interactions, and acts as a proxy to the Video Server. Built with FastAPI or Flask (Python).

## Core Responsibilities
1. **Authentication & Authorization** - JWT tokens, role-based access control
2. **Content Management** - Courses, lessons, materials, quizzes
3. **User Management** - Access control, codes, banning
4. **Analytics** - Watch stats, platform metrics
5. **Video Proxy** - Serve HLS manifests and proxy segments to clients

---

## Data Models

### User Models
```python
class User:
    id: UUID
    email: str (unique)
    password_hash: str
    phone: str
    role: Enum["student", "instructor", "admin", "super_admin"]
    created_at: datetime
    last_login: datetime
    banned_until: datetime | None

class UserProfile:
    id: UUID
    user_id: UUID (FK)
    first_name: str
    last_name: str
    avatar_url: str | None

class UserCourseAccess:
    id: UUID
    user_id: UUID (FK)
    course_id: UUID (FK)
    access_type: Enum["full", "limited", "trial"]
    expires_at: datetime | None
    granted_by: UUID (FK -> User.id)
    created_at: datetime
```

### Content Models
```python
class Course:
    id: UUID
    title: str
    description: str
    instructor_id: UUID (FK -> User.id)
    tags: List[str]  # ["default", "math", "python", etc]
    visibility: Enum["public", "private", "restricted"]
    thumbnail_url: str | None
    created_at: datetime
    updated_at: datetime

class Lesson:
    id: UUID
    course_id: UUID (FK -> Course.id)
    title: str
    description: str
    order: int
    video_id: UUID | None (FK -> Video.id in Video Server)
    lock_type: Enum["none", "previous_lesson", "quiz"]
    quiz_id: UUID | None (FK -> Quiz.id)
    is_published: bool
    created_at: datetime
    updated_at: datetime

class Material:
    id: UUID
    lesson_id: UUID (FK -> Lesson.id)
    type: Enum["pdf", "document", "link", "image"]
    title: str
    url: str  # Can be internal or external
    file_size: int | None
    created_at: datetime

class Quiz:
    id: UUID
    lesson_id: UUID (FK -> Lesson.id)
    title: str
    description: str | None
    passing_score: float (0-100)
    time_limit: int | None  # minutes
    created_at: datetime

class Question:
    id: UUID
    quiz_id: UUID (FK -> Quiz.id)
    type: Enum["multiple_choice", "true_false", "short_answer"]
    question: str
    options: List[str] | None  # JSON array
    correct_answer: str
    points: float = 1.0
    order: int

class QuizAttempt:
    id: UUID
    user_id: UUID (FK -> User.id)
    quiz_id: UUID (FK -> Quiz.id)
    answers: Dict[str, str]  # question_id -> answer
    score: float | None
    passed: bool | None
    started_at: datetime
    completed_at: datetime | None
```

### Interaction Models
```python
class Comment:
    id: UUID
    user_id: UUID (FK -> User.id)
    lesson_id: UUID (FK -> Lesson.id)
    content: str
    parent_id: UUID | None (FK -> Comment.id for replies)
    is_edited: bool = False
    created_at: datetime
    updated_at: datetime

class Report:
    id: UUID
    user_id: UUID (FK -> User.id)
    target_type: Enum["lesson", "comment", "quiz", "user", "material"]
    target_id: UUID
    reason: str
    description: str | None
    status: Enum["pending", "reviewed", "resolved", "rejected"]
    resolved_by: UUID | None (FK -> User.id)
    resolved_at: datetime | None
    created_at: datetime

class Message:
    id: UUID
    sender_id: UUID (FK -> User.id)
    recipient_id: UUID (FK -> User.id)
    content: str
    is_read: bool = False
    created_at: datetime
```

### Access Code Models
```python
class AccessCode:
    id: UUID
    code: str (unique, indexed)
    created_by: UUID (FK -> User.id)
    course_id: UUID | None (FK -> Course.id)
    lesson_id: UUID | None (FK -> Lesson.id)
    access_type: Enum["full", "limited"]
    access_duration: int | None  # days
    expires_at: datetime | None
    max_uses: int | None
    current_uses: int = 0
    is_active: bool = True
    created_at: datetime
    used_at: datetime | None

class AccessCodeUse:
    id: UUID
    access_code_id: UUID (FK -> AccessCode.id)
    user_id: UUID (FK -> User.id)
    used_at: datetime
```

### Analytics Models
```python
class WatchHistory:
    id: UUID
    user_id: UUID (FK -> User.id)
    lesson_id: UUID (FK -> Lesson.id)
    watch_time: float  # seconds
    completion_percentage: float (0-100)
    last_position: float  # seconds
    device_info: str | None
    created_at: datetime
    updated_at: datetime

class UserActivity:
    id: UUID
    user_id: UUID (FK -> User.id)
    action: Enum["login", "logout", "view_course", "view_lesson", "complete_quiz", "download_material", "submit_code"]
    target_type: str | None
    target_id: UUID | None
    metadata: Dict | None  # JSON
    ip_address: str | None
    created_at: datetime
```

---

## API Routes

### Authentication Routes (`/api/v1/auth`)
| Method | Endpoint | Description | Access |
|--------|----------|-------------|--------|
| POST | /login | User login | Public |
| POST | /logout | User logout | Authenticated |
| POST | /register | Create user (admin only) | Admin |
| POST | /refresh | Refresh JWT token | Authenticated |
| GET | /me | Get current user | Authenticated |
| PUT | /me | Update current user profile | Authenticated |
| PUT | /me/password | Change password | Authenticated |

### User Management Routes (`/api/v1/users`)
| Method | Endpoint | Description | Access |
|--------|----------|-------------|--------|
| GET | /users | List users | Admin |
| GET | /users/{user_id} | Get user details | Admin |
| POST | /users | Create user | Admin |
| PUT | /users/{user_id} | Update user | Admin |
| DELETE | /users/{user_id} | Delete user | Admin |
| POST | /users/{user_id}/ban | Ban user | Admin |
| POST | /users/{user_id}/unban | Unban user | Admin |
| POST | /users/{user_id}/access | Grant course access | Admin/Instructor |
| DELETE | /users/{user_id}/access/{access_id} | Revoke course access | Admin/Instructor |
| GET | /users/me/courses | Get my accessible courses | Authenticated |

### Course Routes (`/api/v1/courses`)
| Method | Endpoint | Description | Access |
|--------|----------|-------------|--------|
| GET | /courses | List accessible courses | Authenticated |
| GET | /courses/{course_id} | Get course details | Authenticated |
| POST | /courses | Create course | Admin/Instructor |
| PUT | /courses/{course_id} | Update course | Admin/Instructor (own only) |
| DELETE | /courses/{course_id} | Delete course | Admin/Instructor (own only) |
| GET | /courses/{course_id}/lessons | List course lessons | Authenticated |
| GET | /courses/{course_id}/stats | Get course statistics | Admin/Instructor (own only) |

### Lesson Routes (`/api/v1/lessons`)
| Method | Endpoint | Description | Access |
|--------|----------|-------------|--------|
| GET | /lessons/{lesson_id} | Get lesson details | Authenticated |
| POST | /lessons | Create lesson | Admin/Instructor |
| PUT | /lessons/{lesson_id} | Update lesson | Admin/Instructor (own course) |
| DELETE | /lessons/{lesson_id} | Delete lesson | Admin/Instructor (own course) |
| GET | /lessons/{lesson_id}/materials | Get lesson materials | Authenticated |
| POST | /lessons/{lesson_id}/materials | Add material | Admin/Instructor |
| GET | /lessons/{lesson_id}/comments | Get lesson comments | Authenticated |
| POST | /lessons/{lesson_id}/comments | Add comment | Authenticated |

### Quiz Routes (`/api/v1/quizzes`)
| Method | Endpoint | Description | Access |
|--------|----------|-------------|--------|
| GET | /quizzes/{quiz_id} | Get quiz details | Authenticated |
| POST | /quizzes | Create quiz | Admin/Instructor |
| PUT | /quizzes/{quiz_id} | Update quiz | Admin/Instructor |
| DELETE | /quizzes/{quiz_id} | Delete quiz | Admin/Instructor |
| POST | /quizzes/{quiz_id}/submit | Submit quiz answers | Authenticated |
| GET | /quizzes/{quiz_id}/results | Get quiz results | Authenticated |

### Material Routes (`/api/v1/materials`)
| Method | Endpoint | Description | Access |
|--------|----------|-------------|--------|
| GET | /materials/{material_id} | Download material | Authenticated |
| POST | /materials | Upload material | Admin/Instructor |
| DELETE | /materials/{material_id} | Delete material | Admin/Instructor |

### Access Code Routes (`/api/v1/codes`)
| Method | Endpoint | Description | Access |
|--------|----------|-------------|--------|
| GET | /codes | List generated codes | Admin/Instructor |
| POST | /codes | Generate access code | Admin/Instructor |
| GET | /codes/{code} | Get code details | Admin/Instructor |
| POST | /codes/validate | Validate and use code | Authenticated |
| DELETE | /codes/{code_id} | Deactivate code | Admin/Instructor |

### Video Proxy Routes (`/api/v1/videos`)
| Method | Endpoint | Description | Access |
|--------|----------|-------------|--------|
| GET | /videos/{lesson_id}/manifest | Get HLS manifest URL | Authenticated |
| GET | /videos/{lesson_id}/stream | Get video stream URL | Authenticated |

### Report Routes (`/api/v1/reports`)
| Method | Endpoint | Description | Access |
|--------|----------|-------------|--------|
| GET | /reports | List reports | Admin/Instructor |
| POST | /reports | Submit report | Authenticated |
| PUT | /reports/{report_id} | Update report status | Admin/Instructor |
| GET | /reports/{report_id} | Get report details | Admin/Instructor |

### Statistics Routes (`/api/v1/stats`)
| Method | Endpoint | Description | Access |
|--------|----------|-------------|--------|
| GET | /stats/overview | Platform overview stats | Admin |
| GET | /stats/users | User statistics | Admin |
| GET | /stats/courses/{course_id} | Course-specific stats | Admin/Instructor |
| GET | /stats/instructors | Instructor stats | Super Admin |
| POST | /stats/watch | Record watch progress | Authenticated |

### Message Routes (`/api/v1/messages`)
| Method | Endpoint | Description | Access |
|--------|----------|-------------|--------|
| GET | /messages | Get my messages | Authenticated |
| GET | /messages/{message_id} | Get message | Authenticated |
| POST | /messages | Send message | Authenticated |
| PUT | /messages/{message_id}/read | Mark as read | Authenticated |

---

## Video Server Communication

### Internal API Configuration
```python
# Environment Variables
VIDEO_SERVER_BASE_URL = "http://localhost:8001"  # Default for development
VIDEO_SERVER_INTERNAL_TOKEN = "internal-service-token"

# Endpoints called by Main Server:
# - POST {VIDEO_SERVER_BASE_URL}/api/v1/internal/transcode
# - GET {VIDEO_SERVER_BASE_URL}/api/v1/internal/videos/{video_id}/manifest
# - DELETE {VIDEO_SERVER_BASE_URL}/api/v1/internal/videos/{video_id}
# - GET {VIDEO_SERVER_BASE_URL}/api/v1/internal/videos/{video_id}/segments
```

### Transcoding Request
```python
class TranscodeRequest:
    lesson_id: UUID
    video_url: str  # Uploaded video URL
    watermark_enabled: bool
    watermark_template: str  # "User: {username} | ID: {user_id} | Phone: {phone}"
    resolutions: List[str] = ["240p", "480p", "720p", "1080p"]
    watermark_count: int = 10  # Number of watermarks per video
```

---

## Database Configuration
```python
# Environment Variables
DATABASE_URL = "postgresql://user:password@localhost:5432/lec_main"

# Tables:
# - users
# - user_profiles
# - user_course_access
# - courses
# - lessons
# - materials
# - quizzes
# - questions
# - quiz_attempts
# - comments
# - reports
# - messages
# - access_codes
# - access_code_uses
# - watch_history
# - user_activities
```

---

## Development Configuration

### Environment Variables
```bash
# Server
MAIN_SERVER_HOST=0.0.0.0
MAIN_SERVER_PORT=8000
MAIN_SERVER_DEBUG=true

# Database
DATABASE_URL=postgresql://lec:lec@localhost:5432/lec_main

# JWT
JWT_SECRET_KEY=dev-secret-key-change-in-production
JWT_ALGORITHM=HS256
JWT_ACCESS_TOKEN_EXPIRE_MINUTES=30
JWT_REFRESH_TOKEN_EXPIRE_DAYS=7

# Video Server
VIDEO_SERVER_BASE_URL=http://localhost:8001
VIDEO_SERVER_INTERNAL_TOKEN=dev-internal-token

# CORS
CORS_ORIGINS=http://localhost:3000,http://localhost:8080
```

### Quick Config Change
To change the Video Server URL for testing/production:
```bash
export VIDEO_SERVER_BASE_URL=https://video. Lec.com
# Or create a .env file in main-server/
```

---

## Security Notes
- All routes (except /auth/login, /auth/register) require JWT authentication
- Role-based access control enforced at route level
- Access codes validated before granting course access
- All video requests proxied through Main Server for access control
- User-specific watermarks generated per video request

---

---

## Development Prompt

You are a backend developer working on the Main Server (FastAPI/Flask Python). 

### Your Task
Implement the data models, API routes, and functionality as defined in this document.

### Key Requirements
1. **DO NOT CHANGE** any model structure, route path, or component name
2. Start with the default local configuration:
   - `DATABASE_URL=postgresql://lec:lec@localhost:5432/lec_main`
   - `VIDEO_SERVER_BASE_URL=http://localhost:8001`
   - JWT secrets for development only
3. To change the Video Server URL for testing:
   ```bash
   export VIDEO_SERVER_BASE_URL=https://video.LEC.com
   ```
4. All routes must be under `/api/v1/` prefix
5. Implement role-based access control
6. Video requests ALWAYS go through Main Server proxy

### Database
- PostgreSQL (separate from Video Server DB)
- Run migrations in `/home/pxy/projects/lec/main-server/db/`

### Quick Start
```bash
cd /home/pxy/projects/lec/main-server
cp .env.example .env  # Edit defaults
pip install -r requirements.txt
python -m uvicorn app.main:app --reload
```

### Verification
Run tests and typecheck before committing:
```bash
pytest
ruff check .
mypy .
```

---

## Models NOT to Change
- User model fields and enums
- Course, Lesson, Material, Quiz, Question structures
- API route paths and methods
- Authentication flow
- Access code format
- JWT token structure
