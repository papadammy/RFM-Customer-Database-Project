import pandas as pd
from sqlalchemy import create_engine
from sqlalchemy.engine import URL

# ==============================
# 1. DATABASE CONNECTION
# ==============================
url = URL.create(
    drivername="mysql+pymysql",
    username="root",
    password="@Kayode101",
    host="localhost",
    database="rfm_customer"
)

engine = create_engine(url)

# ==============================
# 2. OUTPUT PATH
# ==============================
output_path = r"C:\Users\PapaDammy\Desktop\Portfolio Projects\Project 4\exports"

# ==============================
# 3. TABLES TO EXPORT
# ==============================
tables = [
    "customer_rfm_base",
    "customer_rfm_scores",
    "customer_segments"
]

# ==============================
# 4. EXPORT LOOP
# ==============================
for table in tables:
    print(f"Exporting {table}...")

    df = pd.read_sql(f"SELECT * FROM {table}", engine)

    file_path = f"{output_path}\\{table}.csv"
    df.to_csv(file_path, index=False)

    print(f"{table} exported successfully!")

print("All tables exported!")