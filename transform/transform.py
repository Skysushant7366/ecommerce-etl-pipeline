import pandas as pd
from datetime import datetime

def parse(x):
    """Handle column whether it's already a dict/list or a string."""
    if isinstance(x, (dict, list)):
        return x
    import ast
    return ast.literal_eval(x)

def transform_products(df):
    print("Transforming products...")
    df["rating_rate"]  = df["rating"].apply(lambda x: parse(x)["rate"])
    df["rating_count"] = df["rating"].apply(lambda x: parse(x)["count"])
    df = df.drop(columns=["rating"])
    df["title"]        = df["title"].str.strip()
    df["category"]     = df["category"].str.strip().str.lower()
    df["price"]        = df["price"].astype(float).round(2)
    df["rating_rate"]  = df["rating_rate"].astype(float)
    df = df.drop_duplicates(subset=["id"])
    df["price_tier"]   = pd.cut(
        df["price"],
        bins=[0, 20, 50, 100, 999],
        labels=["Budget", "Mid", "Premium", "Luxury"]
    )
    df["high_rated"]  = df["rating_rate"] >= 4.0
    df["loaded_at"]   = datetime.now()
    print(f"  ✅ {len(df)} products transformed")
    return df

def transform_carts(df):
    print("Transforming carts...")
    rows = []
    for _, row in df.iterrows():
        products = parse(row["products"])
        for item in products:
            rows.append({
                "cart_id"   : row["id"],
                "user_id"   : row["userId"],
                "date"      : row["date"],
                "product_id": item["productId"],
                "quantity"  : item["quantity"]
            })
    cart_df = pd.DataFrame(rows)
    cart_df["date"]      = pd.to_datetime(cart_df["date"])
    cart_df["quantity"]  = cart_df["quantity"].astype(int)
    cart_df["loaded_at"] = datetime.now()
    print(f"  ✅ {len(cart_df)} cart line items transformed")
    return cart_df

def transform_users(df):
    print("Transforming users...")
    df["full_name"] = df["name"].apply(lambda x: f"{parse(x)['firstname']} {parse(x)['lastname']}")
    df["city"]      = df["address"].apply(lambda x: parse(x)["city"])
    df["zipcode"]   = df["address"].apply(lambda x: parse(x)["zipcode"])
    df = df.drop(columns=["name", "address", "__v"], errors="ignore")
    df["email"]     = df["email"].str.lower().str.strip()
    df["username"]  = df["username"].str.strip()
    df["loaded_at"] = datetime.now()
    print(f"  ✅ {len(df)} users transformed")
    return df

def run_transform():
    print("\n🚀 Starting transformation:", datetime.now())
    products = pd.read_csv("extract/raw_products.csv")
    carts    = pd.read_csv("extract/raw_carts.csv")
    users    = pd.read_csv("extract/raw_users.csv")
    products_clean = transform_products(products)
    carts_clean    = transform_carts(carts)
    users_clean    = transform_users(users)
    products_clean.to_csv("transform/clean_products.csv", index=False)
    carts_clean.to_csv("transform/clean_carts.csv",       index=False)
    users_clean.to_csv("transform/clean_users.csv",       index=False)
    print("\n✅ Transformation complete. Clean files saved.")
    return products_clean, carts_clean, users_clean

if __name__ == "__main__":
    run_transform()