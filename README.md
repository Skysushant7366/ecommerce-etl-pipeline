# 🚀 AI-Driven Omnichannel E-Commerce ERP & CRM Engine

![BigQuery](https://img.shields.io/badge/Google_BigQuery-Data_Warehouse-blue?style=flat-square&logo=googlecloud)
![dbt](https://img.shields.io/badge/dbt-Data_Transformation-FF694B?style=flat-square&logo=dbt)
![Python](https://img.shields.io/badge/Python-AI_Engine-3776AB?style=flat-square&logo=python)
![XGBoost](https://img.shields.io/badge/XGBoost-Predictive_ML-blue?style=flat-square)
![Power BI](https://img.shields.io/badge/Power_BI-Executive_Dashboard-F2C811?style=flat-square&logo=powerbi)

## 📌 Executive Summary
An end-to-end automated **Techno-Functional Data Architecture** built on top of the `thelook_ecommerce` dataset. This project does not just stop at data analysis; it acts as a proactive **Business Rule Engine** that predicts customer behavior, prevents margin bleed, and automates hyper-personalized marketing using Generative AI.

---

## 💼 The Business Case (As-Is vs. To-Be)

### 🔴 The Problem (As-Is State)
Upon analyzing the raw transactional data, the legacy system was found to be entirely reactive:
* **Margin Bleed:** Flat 20% discounts were given blindly, even to price-inelastic (brand-loyal) customers.
* **Fraud & Return Risks:** Serial returners and zero-day bots were processing orders seamlessly, draining logistics budgets.
* **Dead Capital:** Unsold inventory tied up capital with no real-time surge pricing mechanisms.

### 🟢 The Solution (To-Be Architecture)
I designed and executed an automated **To-Be Pipeline** using Agile methodologies. The solution sits at the intersection of Data Engineering, Machine Learning, and Finance:
1. **dbt SQL Brain:** Transforms raw data into 25 Behavioral Pillars and 12 Multivariate Economic Models.
2. **Sequential AI Engine (Colab):** A chained Python MLOps pipeline that predicts Fraud, Return Risk, Churn Probability, and Future LTV.
3. **Business Logic Layer:** Resolves conflicts between AI predictions and actual Unit Economics (e.g., *Blocking COD for high-risk users, applying Surge Pricing for low-inventory/high-demand products*).

---

## 📐 Enterprise Architecture

*(The pipeline is fully automated. dbt Cloud triggers at 1:30 AM IST, followed by GitHub Actions triggering the serverless Google Colab AI engine at 2:30 AM IST).*

![Architecture Diagram](architecture.png) 
*(Note: Upload your draw.io exported image to your repo and name it `architecture.png`)*

---

## 🛠️ The 7-Act Execution Pipeline

### 1. Data Ingestion & Staging 
* Extracted raw logs (Clickstream, Users, Orders, Inventory) from BigQuery.
* Modeled initial staging layers (`stg_events`, `fct_order_items`) resolving data inconsistencies.

### 2. Feature Engineering (The 25 Pillars in dbt)
Engineered 25 advanced data marts using heavy SQL concepts:
* **UX & Intent:** Mapped 'Rage Clicks' and Cart Abandonment ratios.
* **Geospatial Math:** Used `ST_DISTANCE` to calculate warehouse-to-doorstep freight costs and true profit margins.
* **Demographics:** Grouped generational cohorts and climatic seasonal buying patterns.

### 3. Advanced Mathematical Models (SQL)
* **Price Elasticity (Model 08B):** Leveraged `LAG()` window functions to measure demand sensitivity to price drops.
* **Recursive Purchase Chain (Model 07B):** Deployed `WITH RECURSIVE` CTEs to track exact cross-category purchase lifecycles (e.g., *Intimates ➔ Jeans*).
* **Survival Probability (Model 08C):** Applied exponential decay algorithms to derive real-time RFM-based churn risks.

### 4. The Great Filter & AI Gatekeeper
* **Zero-Day Anomaly Detection:** Implemented an **Isolation Forest** to catch new bot patterns based on session latency and click-velocity.
* Data Leakage was strictly prevented by dropping highly correlated "cheat code" columns before passing data to the XGBoost classifiers.

### 5. Chained Predictive Engine (Python MLOps)
Developed an 8-Link Sequential AI brain:
* **Link 2 (Return Risk):** Handled class imbalance using `scale_pos_weight`.
* **Link 3 (Churn Risk):** Inherited Return probabilities to predict 30-day churn.
* **Link 4 (LTV Forecaster):** Utilized **XGBRegressor** to forecast 90-day continuous dollar spend.

### 6. The 5-Phase Business Rules Engine
Merged the AI Customer Predictions with Product Economics (True Margin & GMROI) to generate actionable text-based commands:
* *Example 1:* If LTV is high but Product Margin is Negative ➔ **Trigger: Cross-sell high-margin accessories only.**
* *Example 2:* If Stock is <15 days & Demand is Inelastic ➔ **Trigger: Apply Surge Pricing (+15%).**

### 7. Gen-AI & Omnichannel Delivery
* Passed the finalized segments to the **Gemini API** to generate targeted, hyper-personalized email/push notification copy.
* Pruned the 100+ column dataset into a lightweight **27-Column Lethal Table**.
* Exported final data back to BigQuery, triggering a **Power Automate Webhook** to alert stakeholders, updating the Live **Power BI Executive Dashboard**.

---

## ⚙️ Tech Stack
* **Cloud & DWH:** Google Cloud Platform (GCP), BigQuery
* **Data Engineering:** dbt (Data Build Tool), Advanced SQL (Recursive CTEs, Window Functions, Geospatial)
* **Data Science / AI:** Python, Pandas, Scikit-Learn, XGBoost, Isolation Forest
* **Gen AI:** Google Gemini API
* **Orchestration / CI/CD:** GitHub Actions, Papermill (Serverless Colab execution)
* **BI & Visualization:** Power BI (DirectQuery/Import), Draw.io
* **Business Analysis:** Gap Analysis, As-Is/To-Be Modeling, Agile/Scrum, Traceability, Unit Economics

---

## 👨‍💻 About The Author
**Sushant Kumar Yadav**  
*Techno-Functional Data Professional | Certified Microsoft Business Analyst*  
I specialize in bridging the gap between core business problems and high-end technical architectures. Feel free to connect with me on [LinkedIn](YOUR_LINKEDIN_URL_HERE) or explore my code!
