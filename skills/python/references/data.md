# Python Data Processing Reference

> Load when: user asks about pandas, numpy, CSV/JSON processing, large files, data transformation, or data pipelines.

## Generators for large files (memory-efficient)

```python
from pathlib import Path
from typing import Iterator
import json

# Process large CSV line by line — never load all into memory
def iter_csv_rows(path: Path) -> Iterator[dict]:
    import csv
    with open(path, newline="", encoding="utf-8") as f:
        yield from csv.DictReader(f)

# Process large JSON lines file (JSONL)
def iter_jsonl(path: Path) -> Iterator[dict]:
    with open(path, encoding="utf-8") as f:
        for line in f:
            line = line.strip()
            if line:
                yield json.loads(line)

# Chunked processing
def chunks(iterator, size: int):
    chunk = []
    for item in iterator:
        chunk.append(item)
        if len(chunk) >= size:
            yield chunk
            chunk = []
    if chunk:
        yield chunk

# Usage: process 1M rows in chunks of 1000
for batch in chunks(iter_csv_rows(Path("big.csv")), size=1000):
    insert_many(batch)
```

## pandas

```python
import pandas as pd
from pathlib import Path

# Read
df = pd.read_csv("data.csv", encoding="utf-8")
df = pd.read_json("data.json")
df = pd.read_excel("data.xlsx", sheet_name="Sheet1")
df = pd.read_parquet("data.parquet")  # fastest for large datasets

# Inspect
df.shape          # (rows, cols)
df.dtypes         # column types
df.head(5)
df.describe()     # stats summary
df.info()         # nulls + types

# Select
df["col"]                        # Series
df[["col1", "col2"]]             # DataFrame
df.loc[df["age"] > 18]           # filter by condition
df.loc[df["city"].isin(["TLV", "NYC"])]
df.query("age > 18 and active == True")  # SQL-like

# Transform
df["full_name"] = df["first"] + " " + df["last"]
df["score"] = df["score"].fillna(0)
df = df.drop_duplicates(subset=["email"])
df = df.rename(columns={"old_name": "new_name"})
df["category"] = df["category"].astype("category")

# Group and aggregate
summary = (
    df.groupby("department")
    .agg(
        count=("id", "count"),
        avg_salary=("salary", "mean"),
        max_salary=("salary", "max"),
    )
    .reset_index()
)

# Merge / join
merged = pd.merge(df_users, df_orders, on="user_id", how="left")

# Pivot
pivot = df.pivot_table(
    values="sales",
    index="month",
    columns="region",
    aggfunc="sum",
    fill_value=0,
)

# Apply function
df["normalized"] = df["value"].apply(lambda x: (x - x.min()) / (x.max() - x.min()))

# Write
df.to_csv("out.csv", index=False, encoding="utf-8")
df.to_json("out.json", orient="records", force_ascii=False)
df.to_parquet("out.parquet", index=False)
```

## numpy

```python
import numpy as np

# Array creation
arr = np.array([1, 2, 3, 4, 5], dtype=np.float64)
zeros = np.zeros((3, 4))
ones = np.ones((3, 4))
rng = np.random.default_rng(seed=42)
rand = rng.random((3, 4))
arange = np.arange(0, 10, 0.5)
linspace = np.linspace(0, 1, 100)

# Operations (vectorized — no loops needed)
arr * 2
arr + arr
np.sqrt(arr)
np.mean(arr), np.std(arr), np.median(arr)

# Indexing and slicing
matrix = np.array([[1, 2, 3], [4, 5, 6], [7, 8, 9]])
matrix[0]          # first row
matrix[:, 1]       # second column
matrix[1:, :2]     # slice

# Boolean mask
mask = arr > 3
arr[mask]          # [4, 5]
arr[arr % 2 == 0]  # even elements

# Matrix operations
A = np.array([[1, 2], [3, 4]])
B = np.array([[5, 6], [7, 8]])
np.dot(A, B)       # matrix multiply
A @ B              # same, modern syntax
np.linalg.inv(A)
np.linalg.det(A)
```

## Data transformation patterns

```python
from dataclasses import dataclass
from typing import TypeVar, Callable

T = TypeVar("T")
U = TypeVar("U")

# Pipeline pattern
def pipeline(*fns: Callable) -> Callable:
    def apply(value):
        for fn in fns:
            value = fn(value)
        return value
    return apply

clean = pipeline(
    str.strip,
    str.lower,
    lambda s: s.replace("-", "_"),
)
clean("  Hello-World  ")  # "hello_world"

# Batch transform with error isolation
def safe_transform(items: list[T], fn: Callable[[T], U]) -> tuple[list[U], list[Exception]]:
    results, errors = [], []
    for item in items:
        try:
            results.append(fn(item))
        except Exception as e:
            errors.append(e)
    return results, errors
```

## JSON processing patterns

```python
import json
from pathlib import Path

# Pretty print
print(json.dumps(data, indent=2, ensure_ascii=False, default=str))

# Custom serializer (handles datetime, Pydantic, etc.)
from datetime import datetime
from pydantic import BaseModel

def json_default(obj):
    if isinstance(obj, datetime):
        return obj.isoformat()
    if isinstance(obj, BaseModel):
        return obj.model_dump()
    raise TypeError(f"Not serializable: {type(obj)}")

json.dumps(data, default=json_default)

# Stream large JSON arrays (ijson)
import ijson

with open("large.json", "rb") as f:
    for item in ijson.items(f, "item"):
        process(item)
```

## Environment variables and config

```python
import os
from pydantic_settings import BaseSettings  # pip install pydantic-settings

class Settings(BaseSettings):
    database_url: str
    redis_url: str = "redis://localhost:6379"
    debug: bool = False
    max_workers: int = 4
    api_key: str

    model_config = {"env_file": ".env", "env_file_encoding": "utf-8"}

settings = Settings()  # validates on startup, raises if required vars missing
print(settings.database_url)  # str, not str | None
```
