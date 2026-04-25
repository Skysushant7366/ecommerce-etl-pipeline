from prefect import flow, task
from datetime import datetime
from pathlib import Path
from dotenv import load_dotenv

load_dotenv(dotenv_path=Path(__file__).parent.parent / ".env")

import sys
sys.path.append(str(Path(__file__).parent.parent))

from extract.extract import extract_products, extract_carts, extract_users
from transform.transform import transform_products, transform_carts, transform_users
from load.load import get_engine, create_tables, load_table

@task(name="Extract Products")
def task_extract_products():
    return extract_products()

@task(name="Extract Carts")
def task_extract_carts():
    return extract_carts()

@task(name="Extract Users")
def task_extract_users():
    return extract_users()

@task(name="Transform Products")
def task_transform_products(df):
    return transform_products(df)

@task(name="Transform Carts")
def task_transform_carts(df):
    return transform_carts(df)

@task(name="Transform Users")
def task_transform_users(df):
    return transform_users(df)

@task(name="Load to PostgreSQL")
def task_load_all(products, carts, users):
    engine = get_engine()
    create_tables(engine)
    load_table(products, "products", engine)
    load_table(carts,    "carts",    engine)
    load_table(users,    "users",    engine)

@flow(name="Ecommerce ETL Pipeline", log_prints=True)
def ecommerce_etl():
    print(f"\n🚀 Pipeline started: {datetime.now()}")
    raw_products = task_extract_products()
    raw_carts    = task_extract_carts()
    raw_users    = task_extract_users()
    clean_products = task_transform_products(raw_products)
    clean_carts    = task_transform_carts(raw_carts)
    clean_users    = task_transform_users(raw_users)
    task_load_all(clean_products, clean_carts, clean_users)
    print(f"✅ Pipeline complete: {datetime.now()}")

if __name__ == "__main__":
    ecommerce_etl()