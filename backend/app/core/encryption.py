import base64
import json
import os
from cryptography.hazmat.primitives.ciphers.aead import AESGCM


class AESEncryption:
    """
    AES-256-GCM authenticated encryption for exam questions.
    Each exam session gets a fresh ephemeral key.
    """

    @staticmethod
    def generate_key() -> bytes:
        """Generate a new 256-bit AES key."""
        return AESGCM.generate_key(bit_length=256)

    @staticmethod
    def encrypt(plaintext: str | dict | list, key: bytes) -> dict:
        """
        Encrypt plaintext using AES-256-GCM.

        Args:
            plaintext: String, dict or list to encrypt (dicts/lists auto-serialized to JSON)
            key: 32-byte AES key

        Returns:
            dict with base64-encoded 'ciphertext' and 'iv'
        """
        if isinstance(plaintext, (dict, list)):
            plaintext = json.dumps(plaintext)

        plaintext_bytes = plaintext.encode("utf-8")
        iv = os.urandom(12)   # 96-bit nonce for GCM

        aesgcm = AESGCM(key)
        ciphertext = aesgcm.encrypt(iv, plaintext_bytes, associated_data=None)

        return {
            "ciphertext": base64.b64encode(ciphertext).decode(),
            "iv": base64.b64encode(iv).decode(),
        }

    @staticmethod
    def decrypt(ciphertext_b64: str, iv_b64: str, key: bytes) -> str:
        """
        Decrypt AES-256-GCM ciphertext.

        Returns:
            Decrypted plaintext string

        Raises:
            ValueError: If decryption fails (wrong key or tampered data)
        """
        try:
            key_bytes = key
            iv = base64.b64decode(iv_b64)
            ciphertext = base64.b64decode(ciphertext_b64)

            aesgcm = AESGCM(key_bytes)
            plaintext_bytes = aesgcm.decrypt(iv, ciphertext, associated_data=None)
            return plaintext_bytes.decode("utf-8")
        except Exception as e:
            raise ValueError(f"Decryption failed: {e}")

    @staticmethod
    def encrypt_questions(questions: list[dict]) -> dict:
        """
        Encrypt a list of question objects for delivery to exam client.

        Returns:
            {
              'ciphertext': str,
              'iv': str,
              'key': str  (base64 — must be separately secured for transport)
            }
        """
        key = AESEncryption.generate_key()
        result = AESEncryption.encrypt(questions, key)
        result["key"] = base64.b64encode(key).decode()
        return result

    @staticmethod
    def key_to_base64(key: bytes) -> str:
        return base64.b64encode(key).decode()

    @staticmethod
    def key_from_base64(key_b64: str) -> bytes:
        return base64.b64decode(key_b64)
