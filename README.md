# Ukrainian EV Market Analytics (2023–2025): End-to-End Data Pipeline

An end-to-end data engineering and business intelligence project that processes, cleans, and visualizes open-source data from the Ministry of Internal Affairs (MIA) of Ukraine. The pipeline handles **6.69+ million rows** of raw vehicle registration data to discover insights into the country's electric vehicle (EV) market growth.

📊 **[Link to Tableau Interactive Dashboard](https://public.tableau.com/views/EVMarketTrendsinUkraine/Dashboard1?:language=en-US&publish=yes&:sid=&:redirect=auth&:display_count=n&:origin=viz_share_link)**
---

## Tech Stack & Architecture
* **Data Engineering (ETL):** Python (`pandas`, `numpy`, `sqlalchemy`)
* **Database & Modeling:** SQL (SQLite)
* **Business Intelligence:** Tableau Desktop

---

## Data Pipeline Architecture

[Raw CSV Files (3 Years, 6.69M+ rows)]
│
▼ (Python ETL)
[Data Cleaning & Validation]
│
▼ (SQLAlchemy chunksize=50000)
[Staging SQL Database]
│
▼ (SQL Transformations & Joins)
[Data Mart (Summary)]
│
▼
[Tableau Dashboard]

---

## Technical Implementation Details

### 1. Python ETL & Data Engineering (ua_transport_etl.ipynb / ua_transport_eda_2025.ipynb)
The primary challenge was handling large historical datasets (2023: 2.12M, 2024: 2.34M, 2025: 2.22M rows) without exhausting RAM.
* **Memory Management:** Implemented data streaming and bulk-loaded the data into the database using `chunksize=50000` via `sqlalchemy`.
* **Data Typization:** Enforced strict data types during `pd.read_csv()` for key categorical fields (`REG_ADDR_KOATUU`, `VIN`, `OPER_CODE`) to prevent mixed-type inference errors.
* **String Standardization:** Handled human-error data entries by cleaning brand names using `.str.upper().str.strip()`, consolidating duplicates like `"Tesla "` and `"TESLA"` into a single dimension.
* **Regex Transformation:** Cleaned weight metrics (`OWN_WEIGHT`, `TOTAL_WEIGHT`) containing European comma separators, converting them via regex to standard floats.
* **Anomaly Filtering:** Removed invalid records with dates outside the 1950–2026 range and dropped rows with critical missing attributes.

### 2. SQL Modeling & Data Mart Development (01_init_and_dimensions.sql / 02_tableau_car_market_mart.sql )
* **Data Consolidation:** Merged yearly staging tables using an optimized `UNION ALL` structure.
* **Geospatial Parsing:** Extracted regional codes by parsing the KOATUU classification codes (`SUBSTR(REG_ADDR_KOATUU, 1, 2)`) and joined them with a standardized Ukrainian regions lookup table.
* **Feature Engineering:** Calculated vehicle age at the moment of registration using conditional logic (`CASE WHEN`) to segment the fleet into commercial age tiers.
* **Performance Optimization:** Built a denormalized data mart (`auto_market_summary`), which significantly reduced the query load for the BI layer and ensured instantaneous dashboard rendering.

### 3. Tableau Dashboard & Analytics
* Developed an executive dashboard highlighting **EV vs. ICE market share dynamics** (EV share grew from 3.87% in 2023 to 9.89% in 2025).
* Created a **Geospatial Heatmap** to identify regions with the highest density of EV adoptions (Top: Kyiv, Lviv, Kyiv Oblast).
* Designed an optimized **Phone Layout** to ensure seamless mobile viewing for business stakeholders.

---

## Repository Structure
* `notebooks/` — Python Jupyter Notebooks / ETL scripts for data extraction and cleaning.
* `sql/` — Queries for database initialization, `UNION ALL` merging, and Data Mart generation.
* `README.md` — Project documentation.
  
