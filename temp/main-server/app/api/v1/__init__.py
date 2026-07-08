from fastapi import APIRouter

from app.api.v1 import auth, users, courses, lessons, quizzes, misc, enrollment, qbanks

api_router = APIRouter(prefix="/v1")

api_router.include_router(auth.router)
api_router.include_router(users.router)
api_router.include_router(courses.router)
api_router.include_router(lessons.router)
api_router.include_router(quizzes.router)
api_router.include_router(qbanks.router)
api_router.include_router(enrollment.router)
api_router.include_router(misc.misc_router)
api_router.include_router(misc.materials_router)
api_router.include_router(misc.codes_router)
api_router.include_router(misc.reports_router)
api_router.include_router(misc.stats_router)
api_router.include_router(misc.messages_router)
api_router.include_router(misc.videos_router)
api_router.include_router(misc.certificates_router)