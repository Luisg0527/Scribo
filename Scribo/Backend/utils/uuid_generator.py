import uuid
import hashlib

def text_to_uuid(text):
    hash_object = hashlib.sha1(text.encode())
    
    hashed_text = hash_object.digest()
    return uuid.UUID(bytes=hashed_text[:16])
