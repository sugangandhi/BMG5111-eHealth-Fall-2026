import time
import random

def analyze_health_card(image_bytes: bytes) -> dict:
    """
    Mock OCR function that simulates extracting data from an Ontario Health Card.
    """
    time.sleep(1.5)
    return {
        "health_card_number": f"{random.randint(1000,9999)}-{random.randint(100,999)}-{random.randint(100,999)}",
        "version_code": random.choice(["AA", "AB", "YM", "ZN", "WX"]),
        "patient_name": "John Doe",
        "dob": "1985-04-12",
        "confidence": round(random.uniform(0.9, 0.99), 2)
    }
