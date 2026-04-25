# 🛒 E-Commerce ETL Pipeline

Automated end-to-end data pipeline for e-commerce analytics.

## 🏗️ Architecture
FakeStore API → Python ETL → PostgreSQL → Prefect → Streamlit

## ⚙️ Stack
- **Extract:** Python requests + FakeStore API
- **Transform:** Pandas (cleaning, KPIs, price tiers)
- **Load:** PostgreSQL + SQLAlchemy
- **Orchestrate:** Prefect automated scheduling
- **Dashboard:** Streamlit + Plotly

## 📊 Features
- 20 products across 4 categories
- Price tier classification (Budget/Mid/Premium/Luxury)
- High rating detection
- Order quantity analysis
- Live auto-refreshing dashboard

## 🚀 Run locally
pip install -r requirements.txt
python orchestrate/pipeline.py
streamlit run dashboard/app.py