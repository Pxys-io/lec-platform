# LEC Video Server - Architecture & Development Guide

## Overview

Video Server handles video transcoding, HLS streaming, watermark injection, and segment management. It serves as a microservice that the Main Server calls for video operations. The Flutter client never directly accesses the Video Server - all video access goes through the Main Server.

## Architecture

```
Main Server (localhost:8000)
    ↓ calls
Video Server (localhost:8001)
    ↓ stores
Local Storage / S3 / R2
```

### Communication Pattern

- Main Server creates video entries → calls Video Server POST `/api/v1/internal/videos`
- Main Server requests manifest → calls Video Server GET `/api/v1/internal/videos/{id}/manifest`
- Main Server streams video → calls Video Server GET `/api/v1/internal/videos/{id}/stream`
- All routes under `/api/v1/internal/` are internal-only (no auth required, Main Server is the only consumer)

## Database Models

### Video (videos table)
Core video metadata stored after upload.

| Field | Type | Description |
|-------|------|-------------|
| id | str (PK) | UUID |
| title | str | Video title |
| description | str (nullable) | Video description |
| original_filename | str | Original upload filename |
| original_path | str | Path to original file on storage |
| duration_seconds | float (nullable) | Duration in seconds |
| width | int (nullable) | Video width |
| height | int (nullable) | Video height |
| codec | str (nullable) | Codec used (h264, hevc, etc.) |
| bitrate | int (nullable) | Bitrate in bps |
| status | str | "pending" | "transcoding" | "ready" | "error" |
| watermark_enabled | bool | Whether to inject watermarks |
| watermark_segments | int | Number of watermark segments to inject |
| watermark_text | str (nullable) | Custom watermark text (username, user_id, etc.) |
| storage_type | str | "local" | "s3" | "r2" |
| storage_path | str (nullable) | Local storage path or S3 key |
| cdn_url | str (nullable) | CDN URL for this video |
| created_by | str (nullable) | User ID who uploaded |
| created_at | datetime | Upload timestamp |
| updated_at | datetime | Last update timestamp |

### VideoResolution (video_resolutions table)
Each transcoded resolution gets its own record.

| Field | Type | Description |
|-------|------|-------------|
| id | str (PK) | UUID |
| video_id | str (FK → videos) | Parent video |
| resolution | str | "360p" | "480p" | "720p" | "1080p" |
| width | int | Resolution width |
| height | int | Resolution height |
| bitrate | int | Target bitrate |
| playlist_url | str (nullable) | URL to .m3u8 playlist |
| segments_count | int | Number of segments |
| total_size_bytes | int | Total size of all segments |
| status | str | "pending" | "ready" | "error" |
| created_at | datetime | Creation timestamp |

### VideoSegment (video_segments table)
Each HLS segment (.ts file) gets its own record. Hashed filenames for security.

| Field | Type | Description |
|-------|------|-------------|
| id | str (PK) | UUID |
| video_id | str (FK → videos) | Parent video |
| resolution_id | str (FK → video_resolutions) | Parent resolution |
| segment_number | int | Order number (0, 1, 2, ...) |
| segment_hash | str | SHA256 hash - never sequential |
| filename | str | Actual filename on disk |
| duration_seconds | float | Segment duration |
| byte_size | int | Segment size in bytes |
| is_watermark | bool | True if this is a watermark segment |
| watermark_text | str (nullable) | Watermark text for this segment |
| storage_type | str | "local" | "s3" | "r2" |
| storage_path | str (nullable) | Full path or S3 key |
| created_at | datetime | Creation timestamp |

### TranscodeJob (transcode_jobs table)
Tracks transcoding operations.

| Field | Type | Description |
|-------|------|-------------|
| id | str (PK) | UUID |
| video_id | str (FK → videos) | Video being transcoded |
| status | str | "pending" | "running" | "completed" | "error" |
| progress | float | 0.0 - 100.0 |
| resolutions_requested | str | Comma-separated list |
| resolutions_completed | str | Comma-separated list of completed |
| error_message | str (nullable) | Error details |
| started_at | datetime (nullable) | When transcoding started |
| completed_at | datetime (nullable) | When transcoding finished |
| created_at | datetime | Job creation timestamp |

### WatchSession (watch_sessions table)
Tracks individual viewing sessions for analytics.

| Field | Type | Description |
|-------|------|-------------|
| id | str (PK) | UUID |
| video_id | str (FK → videos) | Video being watched |
| user_id | str (nullable) | User watching |
| resolution | str | Resolution requested |
| segment_start | int | First segment played |
| segment_end | int | Last segment played |
| completed | bool | Whether the full video was watched |
| created_at | datetime | Session start timestamp |

## API Routes

### Internal API (prefix: `/api/v1/internal/videos`)

All internal routes - called by Main Server only. No authentication required.

#### POST `/api/v1/internal/videos`
Create a video entry after upload.

**Request Body:**
```json
{
  "title": "Video Title",
  "description": "Description",
  "original_filename": "lecture.mp4",
  "original_path": "/uploads/lecture.mp4",
  "watermark_enabled": true,
  "watermark_segments": 10,
  "watermark_text": "user@example.com"
}
```

**Response (200):** Video object

---

#### GET `/api/v1/internal/videos/{video_id}`
Get video details with all resolutions.

**Response (200):** VideoDetailResponse (Video + resolutions list)

---

#### PUT `/api/v1/internal/videos/{video_id}`
Update video metadata.

**Request Body:** Partial update fields

**Response (200):** Updated Video object

---

#### DELETE `/api/v1/internal/videos/{video_id}`
Delete video and all associated segments/resolutions.

**Response (200):** `{"message": "Video deleted successfully"}`

---

#### POST `/api/v1/internal/videos/{video_id}/transcode`
Start transcoding job.

**Query Params:** `resolutions=360p,480p,720p,1080p`

**Response (200):** TranscodeJobResponse

---

#### GET `/api/v1/internal/videos/{video_id}/manifest`
Get manifest with all ready resolutions.

**Response (200):** ManifestResponse

---

#### GET `/api/v1/internal/videos/{video_id}/stream`
Get stream URL for a specific resolution.

**Query Params:** `resolution=720p`

**Response (200):** `{"stream_url": "...", "resolution": "720p"}`

---

#### GET `/api/v1/internal/videos/{video_id}/playlist/{resolution}`
Get HLS playlist (.m3u8) for a resolution.

**Response (200):** Raw .m3u8 playlist content

---

#### GET `/api/v1/internal/videos/{video_id}/segment/{segment_hash}`
Get individual HLS segment (.ts file).

**Response (200):** Binary .ts file

---

#### GET `/api/v1/internal/videos/{video_id}/status`
Get video and resolution status.

**Response (200):** Status object with resolutions list

## Watermark System

### How It Works

1. When a video is transcoded, it is split into N segments (where N = watermark_segments)
2. Every Nth segment is replaced with a watermark segment
3. Watermark segments are 1-second .ts files with the user's info rendered
4. Each segment filename is a hash (not sequential) - prevents tampering
5. The playlist marks watermark segments with `#EXT-X-WATERMARK` tag

### Watermark Injection Flow

```
Original video (60 min) → 600 segments (10 sec each)
    ↓
Every 60th segment → replace with 1-second watermark segment
    ↓
Watermark contains: username, user_id, user_email rendered via ffmpeg overlay
    ↓
Segments hashed: segment_0 → abc123def456.ts, segment_1 → f789abc012de.ts
    ↓
Playlist references hashed filenames only
```

### FFmpeg Watermark Command Pattern

```bash
ffmpeg -i input.mp4 \
  -vf "drawtext=text='user@example.com':x=w-200:y=h-50:fontsize=24:fontcolor=white@0.7" \
  -t 1 \
  watermark_segment.ts
```

## Storage

### Local Storage (default)
- Path: `./storage/videos/{video_id}/{resolution}/{segment_hash}.ts`
- Playlist: `./storage/videos/{video_id}/{resolution}.m3u8`

### S3 / R2
- Bucket configured in settings
- Objects prefixed by video_id
- CDN URL optional for public access

## Development Notes

- Default to localhost:8001 for development
- Change `VIDEO_STORAGE_TYPE` in config for S3/R2
- FFmpeg must be installed on the server for transcoding
- Watermark segments are generated on-the-fly during transcoding
- Segment hashing prevents direct URL guessing
- Always kill any existing server before starting tests

## Testing

Run tests with:
```bash
.venv/bin/python test_api.py
```

The test script handles:
- Killing any existing server
- Starting a fresh server
- Running all tests
- Cleaning up (terminating server)
- Reporting results with pass/fail counts and success rate