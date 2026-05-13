import pandas as pd
from sqlalchemy import create_engine
from sqlalchemy.engine import URL

# ==============================
# 1. DATABASE CONNECTION
# ==============================
url = URL.create(
    drivername="mysql+pymysql",
    username="root",
    password="yourDBpassword",  # keep your real password here
    host="localhost",
    database="rfm_customer"
)

engine = create_engine(url)

# ==============================
# 2. FILE PATHS
# ==============================

base_path = r"C:\Users\PapaDammy\Desktop\Portfolio Projects\Project 4"


customers_path = f"{base_path}\\olist_customers_dataset.csv"
orders_path = f"{base_path}\\olist_orders_dataset.csv"
order_items_path = f"{base_path}\\olist_order_items_dataset.csv"
payments_path = f"{base_path}\\olist_order_payments_dataset.csv"

# ==============================
# 3. LOAD CUSTOMERS
# ==============================
print("Loading customers...")

df_customers = pd.read_csv(customers_path)

df_customers = df_customers.fillna('')
df_customers['customer_zip_code_prefix'] = pd.to_numeric(
    df_customers['customer_zip_code_prefix'], errors='coerce'
)

df_customers.to_sql(
    "customers",
    con=engine,
    if_exists="append",
    index=False,
    chunksize=1000,
    method="multi"
)

print("Customers loaded!")

# ==============================
# 4. LOAD ORDERS
# ==============================
print("Loading orders...")

df_orders = pd.read_csv(orders_path)

# Convert datetime columns
date_cols_orders = [
    'order_purchase_timestamp',
    'order_approved_at',
    'order_delivered_carrier_date',
    'order_delivered_customer_date',
    'order_estimated_delivery_date'
]

for col in date_cols_orders:
    df_orders[col] = pd.to_datetime(df_orders[col], errors='coerce')

df_orders = df_orders.fillna(None)

df_orders.to_sql(
    "orders",
    con=engine,
    if_exists="append",
    index=False,
    chunksize=1000,
    method="multi"
)

print("Orders loaded!")

# ==============================
# 5. LOAD ORDER ITEMS
# ==============================
print("Loading order items...")

df_items = pd.read_csv(order_items_path)

df_items['shipping_limit_date'] = pd.to_datetime(
    df_items['shipping_limit_date'], errors='coerce'
)

df_items = df_items.fillna(None)

df_items.to_sql(
    "order_items",
    con=engine,
    if_exists="append",
    index=False,
    chunksize=1000,
    method="multi"
)

print("Order items loaded!")

# ==============================
# 6. LOAD PAYMENTS
# ==============================
print("Loading payments...")

df_payments = pd.read_csv(payments_path)

df_payments = df_payments.fillna(None)

df_payments.to_sql(
    "order_payments",
    con=engine,
    if_exists="append",
    index=False,
    chunksize=1000,
    method="multi"
)

print("Payments loaded!")

# ==============================
# DONE
# ==============================
print("All tables loaded successfully!")