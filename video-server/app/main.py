from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware

from app.core.database import init_db
from app.api.v1.internal import videos


app = FastAPI(
    title="LEC Video Server",
    description="Video transcoding, HLS streaming, and watermarking service",
    version="1.0.0",
)

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_methods=["*"],
    allow_headers=["*"],
)

app.include_router(videos.router)


from app.core.worker import worker
from app.core.config import settings

@app.on_event("startup")
def on_startup():
    init_db()
    if not settings.MUX_ENABLED:
        worker.start()

@app.on_event("shutdown")
def on_shutdown():
    if not settings.MUX_ENABLED:
        worker.stop()


@app.get("/")
def root():
    return {"message": "LEC Video Server API", "version": "1.0.0"}


@app.get("/health")
def health():
    return {"status": "healthy"}