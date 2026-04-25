import pandas as pd
from sqlalchemy import create_engine, text
from dotenv import load_dotenv
import os
from datetime import datetime

# Load credentials from .env
from pathlib import Path
load_dotenv(dotenv_path=Path(__file__).parent.parent / ".env")

DB_HOST     = os.getenv("DB_HOST")
DB_PORT     = os.getenv("DB_PORT")
DB_NAME     = os.getenv("DB_NAME")
DB_USER     = os.getenv("DB_USER")
DB_PASSWORD = os.getenv("DB_PASSWORD")

print("HOST:", os.getenv("DB_HOST"))
print("PORT:", os.getenv("DB_PORT"))

def get_engine():
    url = f"postgresql+psycopg2://{DB_USER}:{DB_PASSWORD}@{DB_HOST}:{DB_PORT}/{DB_NAME}"
    engine = create_engine(url)
    return engine

def create_tables(engine):
    print("Creating tables if not exist...")
    with engine.connect() as conn:
        conn.execute(text("""
            CREATE TABLE IF NOT EXISTS products (
                id           INT PRIMARY KEY,
                title        TEXT,
                price        FLOAT,
                category     TEXT,
                description  TEXT,
                image        TEXT,
                rating_rate  FLOAT,
                rating_count INT,
                price_tier   TEXT,
                high_rated   BOOLEAN,
                loaded_at    TIMESTAMP
            );
        """))

        conn.execute(text("""
            CREATE TABLE IF NOT EXISTS carts (
                cart_id     INT,
                user_id     INT,
                date        TIMESTAMP,
                product_id  INT,
                quantity    INT,
                loaded_at   TIMESTAMP
            );
        """))

        conn.execute(text("""
            CREATE TABLE IF NOT EXISTS users (
                id          INT PRIMARY KEY,
                email       TEXT,
                username    TEXT,
                full_name   TEXT,
                city        TEXT,
                zipcode     TEXT,
                phone       TEXT,
                loaded_at   TIMESTAMP
            );
        """))
        conn.commit()
    print("  ✅ Tables ready")

def load_table(df, table_name, engine, if_exists="replace"):
    print(f"Loading {table_name}...")
    df.to_sql(table_name, engine, if_exists=if_exists, index=False)
    print(f"  ✅ {len(df)} rows loaded into {table_name}")

def run_load():
    print("\n🚀 Starting load:", datetime.now())

    # Connect
    engine = get_engine()
    create_tables(engine)

    # Read clean CSVs from transform step
    products = pd.read_csv("transform/clean_products.csv")
    carts    = pd.read_csv("transform/clean_carts.csv")
    users    = pd.read_csv("transform/clean_users.csv")

    # Load into PostgreSQL
    load_table(products, "products", engine)
    load_table(carts,    "carts",    engine)
    load_table(users,    "users",    engine)

    print("\n✅ Load complete. All data in PostgreSQL.")

if __name__ == "__main__":
    run_load()