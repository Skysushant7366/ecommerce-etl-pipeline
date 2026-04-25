import psycopg2

conn = psycopg2.connect(
    host="localhost",
    port=5432,
    user="postgres",
    password="Yadav5430",
    dbname="postgres"
)
conn.autocommit = True
cur = conn.cursor()
cur.execute("CREATE DATABASE ecommerce_etl")
print("✅ Database created!")
conn.close()