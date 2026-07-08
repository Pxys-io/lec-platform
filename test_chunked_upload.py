import requests
import os

MAIN_API = "http://localhost:8000/api/v1"
def test_upload():
    # Login
    r = requests.post(f"{MAIN_API}/auth/login", json={"email":"instructor@lec.com", "password":"instructor123"})
    token = r.json()["access_token"]
    headers = {"Authorization": f"Bearer {token}"}

    # Create dummy file
    with open("dummy.mp4", "wb") as f:
        f.write(b"dummy video content" * 1000)

    size = os.path.getsize("dummy.mp4")

    # Init
    print("Init...")
    r = requests.post(f"{MAIN_API}/videos/upload/init", headers=headers, json={
        "title": "Test Chunked",
        "filename": "dummy.mp4",
        "total_size": size,
        "total_chunks": 1,
        "watermark_enabled": False
    })
    print(r.status_code, r.text)
    upload_id = r.json()["upload_id"]

    # Chunk
    print("Chunk...")
    with open("dummy.mp4", "rb") as f:
        files = {"file": ("dummy.mp4", f, "video/mp4")}
        r = requests.post(f"{MAIN_API}/videos/upload/{upload_id}/chunk?chunk_index=0", headers=headers, files=files)
        print(r.status_code, r.text)

    # Status
    print("Status...")
    r = requests.get(f"{MAIN_API}/videos/upload/{upload_id}/status", headers=headers)
    print(r.status_code, r.text)

    # Complete
    print("Complete...")
    r = requests.post(f"{MAIN_API}/videos/upload/{upload_id}/complete", headers=headers)
    print(r.status_code, r.text)

if __name__ == "__main__":
    test_upload()
