import streamlit as st
import pandas as pd
from sqlalchemy import create_engine
from dotenv import load_dotenv
from pathlib import Path
import plotly.express as px
import os

load_dotenv(dotenv_path=Path(__file__).parent.parent / ".env")

st.set_page_config(page_title="E-Commerce Analytics", layout="wide")

@st.cache_resource
def get_engine():
    url = f"postgresql+psycopg2://{os.getenv('DB_USER')}:{os.getenv('DB_PASSWORD')}@{os.getenv('DB_HOST')}:{os.getenv('DB_PORT')}/{os.getenv('DB_NAME')}"
    return create_engine(url)

@st.cache_data(ttl=300)
def load_data():
    engine = get_engine()
    products = pd.read_sql("SELECT * FROM products", engine)
    carts    = pd.read_sql("SELECT * FROM carts",    engine)
    users    = pd.read_sql("SELECT * FROM users",    engine)
    return products, carts, users

# ── Load ────────────────────────────────────────────────────────────
products, carts, users = load_data()

# ── Header ──────────────────────────────────────────────────────────
st.title("🛒 E-Commerce ETL Dashboard")
st.caption("Live data from PostgreSQL — powered by automated Prefect pipeline")

# ── KPI Cards ───────────────────────────────────────────────────────
k1, k2, k3, k4 = st.columns(4)
k1.metric("Total Products",    len(products))
k2.metric("Total Orders",      len(carts))
k3.metric("Total Users",       len(users))
k4.metric("Avg Product Price", f"${products['price'].mean():.2f}")

st.divider()

# ── Row 1: Category breakdown + Price tier ──────────────────────────
c1, c2 = st.columns(2)

with c1:
    st.subheader("📦 Products by Category")
    cat_df = products.groupby("category").size().reset_index(name="count")
    fig = px.bar(cat_df, x="category", y="count", color="category")
    st.plotly_chart(fig, use_container_width=True)

with c2:
    st.subheader("💰 Price Tier Distribution")
    tier_df = products["price_tier"].value_counts().reset_index()
    tier_df.columns = ["tier", "count"]
    fig2 = px.pie(tier_df, names="tier", values="count", hole=0.4)
    st.plotly_chart(fig2, use_container_width=True)

# ── Row 2: Top rated + Price by category ────────────────────────────
c3, c4 = st.columns(2)

with c3:
    st.subheader("⭐ Top Rated Products")
    top = products[["title", "rating_rate", "price", "category"]].sort_values(
        "rating_rate", ascending=False).head(10)
    top["title"] = top["title"].str[:30] + "..."
    fig3 = px.bar(top, x="rating_rate", y="title", orientation="h", color="category")
    st.plotly_chart(fig3, use_container_width=True)

with c4:
    st.subheader("📊 Avg Price by Category")
    avg_price = products.groupby("category")["price"].mean().reset_index()
    fig4 = px.bar(avg_price, x="category", y="price", color="category")
    st.plotly_chart(fig4, use_container_width=True)

# ── Row 3: Orders + Raw table ────────────────────────────────────────
st.subheader("🛍️ Order Quantities by Product")
order_summary = carts.groupby("product_id")["quantity"].sum().reset_index()
order_summary = order_summary.merge(
    products[["id", "title"]], left_on="product_id", right_on="id"
)
order_summary["title"] = order_summary["title"].str[:30]
fig5 = px.bar(order_summary.sort_values("quantity", ascending=False),
              x="title", y="quantity", color="quantity")
st.plotly_chart(fig5, use_container_width=True)

st.divider()
st.subheader("🗃️ Raw Products Table")
st.dataframe(products[["id","title","category","price","price_tier",
                        "rating_rate","high_rated"]].sort_values("price", ascending=False),
             use_container_width=True)
