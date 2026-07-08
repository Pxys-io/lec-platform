import os
import secrets
import subprocess


def generate_encryption_keypair():
    key_hex = secrets.token_hex(16)
    iv_hex = secrets.token_hex(16)
    return key_hex, iv_hex


def encrypt_segment_file(input_path: str, output_path: str, key_hex: str, iv_hex: str) -> bool:
    result = subprocess.run(
        ["openssl", "enc", "-aes-128-cbc",
         "-K", key_hex, "-iv", iv_hex, "-nosalt",
         "-in", input_path,
         "-out", output_path],
        capture_output=True, text=True
    )
    if result.returncode != 0:
        print(f"Encryption error: {result.stderr[-300:]}")
        return False
    return True


def encrypt_file_inplace(file_path: str, key_hex: str, iv_hex: str) -> bool:
    enc_path = file_path + ".enc_tmp"
    if encrypt_segment_file(file_path, enc_path, key_hex, iv_hex):
        os.replace(enc_path, file_path)
        return True
    return False
