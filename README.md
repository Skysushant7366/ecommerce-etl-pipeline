📊 E-Commerce ETL Pipeline
===========================

An end-to-end automated e-commerce ETL (Extract, Transform, Load) pipeline that extracts data from FakeStore API, transforms it with pandas, loads to PostgreSQL, and visualizes with Streamlit.

## 🏗️ Architecture

```
FakeStore API → Extract → Transform → Load → PostgreSQL
                                          ↓
                                    Streamlit Dashboard
                                    (Prefect Orchestration)
```

## 🔧 Tech Stack

- **Python 3.9+** - Core language
- **PostgreSQL** - Data warehouse
- **Pandas** - Data transformation
- **Requests** - API calls
- **Prefect** - Workflow orchestration
- **Streamlit** - Data visualization
- **psycopg2** - PostgreSQL adapter

## 📋 Prerequisites

- Python 3.9 or higher
- PostgreSQL 12+
- Git

## ⚙️ Installation

### 1. Clone the Repository
```bash
git clone https://github.com/Skysushant7366/ecommerce-etl-pipeline.git
cd ecommerce-etl-pipeline
```

### 2. Create Virtual Environment
```bash
# Windows
python -m venv venv
venv\Scripts\activate

# macOS/Linux
python3 -m venv venv
source venv/bin/activate
```

### 3. Install Dependencies
```bash
pip install -r requirements.txt
```

### 4. Configure Environment
Copy `.env.example` to `.env` and update with your PostgreSQL credentials:
```bash
cp .env.example .env
```

Edit `.env`:
```dotenv
DB_HOST=localhost
DB_PORT=5432
DB_NAME=ecommerce_etl
DB_USER=postgres
DB_PASSWORD=your_new_password
```

### 5. Create Database
```bash
python create_db.py
```

## 🚀 Usage

### Option 1: Run Full ETL Pipeline
```bash
python orchestrate/etl_pipeline.py
```

### Option 2: Run Steps Individually

**Extract:**
```bash
python extract/fakestore_api.py
```

**Transform:**
```bash
python transform/data_transformer.py
```

**Load:**
```bash
python load/postgres_loader.py
```

### Option 3: Launch Streamlit Dashboard
```bash
streamlit run dashboard/app.py
```

Access at: `http://localhost:8501`

## 📁 Project Structure

```
ecommerce-etl-pipeline/
├── extract/
│   ├── __init__.py
│   └── fakestore_api.py         # API data extraction
├── transform/
│   ├── __init__.py
│   └── data_transformer.py       # Data cleaning & transformation
├── load/
│   ├── __init__.py
│   └── postgres_loader.py        # Load to PostgreSQL
├── orchestrate/
│   ├── __init__.py
│   └── etl_pipeline.py          # Prefect workflow
├── dashboard/
│   ├── __init__.py
│   └── app.py                   # Streamlit dashboard
├── .env.example                  # Environment template
├── .gitignore                    # Git ignore rules
├── create_db.py                  # Database initialization
├── requirements.txt              # Python dependencies
└── README.md                     # This file
```

## 📊 Data Flow

1. **Extract**: Fetches products, users, and carts from FakeStore API
2. **Transform**: Cleans data, removes duplicates, handles missing values
3. **Load**: Creates tables and inserts data into PostgreSQL
4. **Visualize**: Streamlit dashboard displays real-time analytics

## 🔐 Security

- ✅ `.env` credentials excluded from Git
- ✅ `.env.example` provided as template
- ✅ Sensitive data never committed
- ✅ Use strong database passwords

## 📝 Features

- ✨ Automated data extraction from REST API
- 🧹 Data cleaning and validation
- 💾 Reliable PostgreSQL loading
- 📊 Real-time Streamlit dashboard
- 🔄 Prefect workflow orchestration
- 🎯 Error handling and logging

## 🐛 Troubleshooting

### PostgreSQL Connection Error
```bash
# Verify PostgreSQL is running
psql -U postgres -h localhost -c "SELECT version();"

# Check credentials in .env
```

### Module Import Error
```bash
# Reinstall requirements
pip install --upgrade -r requirements.txt
```

### Streamlit Port Already in Use
```bash
streamlit run dashboard/app.py --server.port 8502
```

## 📚 API Reference

### FakeStore API Endpoints Used
- `GET /products` - All products
- `GET /users` - All users
- `GET /carts` - All shopping carts

## 🤝 Contributing

1. Fork the repository
2. Create feature branch (`git checkout -b feature/amazing-feature`)
3. Commit changes (`git commit -m 'Add amazing feature'`)
4. Push to branch (`git push origin feature/amazing-feature`)
5. Open Pull Request

## 📄 License

This project is open source and available under the MIT License.

## 👨‍💼 Author

**Skysushant7366** - [GitHub Profile](https://github.com/Skysushant7366)

## 📞 Support

For issues and questions:
- Open a GitHub Issue
- Check existing documentation
- Review error logs

---

**Last Updated**: 2026-04-25
**Status**: ✅ Active Development
