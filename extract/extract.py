import requests
import pandas as pd
import json
from datetime import datetime

# ── FakeStore API (free, no key needed) ──────────────────────────────
BASE_URL = "https://fakestoreapi.com"

def extract_products():
    print("Extracting products...")
    response = requests.get(f"{BASE_URL}/products", timeout=10)
    data = response.json()
    df = pd.DataFrame(data)
    print(f"  ✅ {len(df)} products extracted")
    return df

def extract_carts():
    print("Extracting carts (orders)...")
    response = requests.get(f"{BASE_URL}/carts", timeout=10)
    data = response.json()
    df = pd.DataFrame(data)
    print(f"  ✅ {len(df)} carts extracted")
    return df

def extract_users():
    print("Extracting users...")
    response = requests.get(f"{BASE_URL}/users", timeout=10)
    data = response.json()
    df = pd.DataFrame(data)
    print(f"  ✅ {len(df)} users extracted")
    return df

def run_extract():
    print("\n🚀 Starting extraction:", datetime.now())
    products = extract_products()
    carts    = extract_carts()
    users    = extract_users()

    # Save raw data as CSV (backup)
    products.to_csv("extract/raw_products.csv", index=False)
    carts.to_csv("extract/raw_carts.csv",    index=False)
    users.to_csv("extract/raw_users.csv",    index=False)

    print("\n✅ Extraction complete. Raw files saved.")
    return products, carts, users

if __name__ == "__main__":
    run_extract()
