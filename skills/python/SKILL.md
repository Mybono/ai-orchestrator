---
name: python-mastery
description: >
  Write, review, debug, and improve Python code across any context: CLI scripts,
  automation, data processing, REST APIs (FastAPI/Flask), async code, testing,
  packaging, and CI/CD tooling. Use this skill whenever the user asks to write a
  Python script, debug a Python error, improve existing code, set up a project,
  work with virtual environments, type hints, decorators, async/await, dataclasses,
  Pydantic models, or asks about Python best practices. Also trigger for requests
  involving requirements.txt, pyproject.toml, pytest, pandas, httpx, or any .py file.
---

# Python Mastery Skill

> Python 3.11+ · type hints everywhere · modern tooling (uv / pyproject.toml)

---

## Step 0: Understand before writing

Before writing or reviewing Python code, identify:

1. **Python version** — 3.11+? 3.10? If unspecified, target 3.11+.
2. **Environment** — local script, CI runner, Docker, Lambda, long-running service?
3. **Execution model** — sync or async? (FastAPI → async, scripts → sync)
4. **Packaging** — standalone script, library, or application?
5. **Existing setup** — `pyproject.toml` or `requirements.txt`? `venv`, `uv`, `poetry`?

If the user pastes a traceback, diagnose it first — skip the interview.

---

## Project Setup

### Recommended: uv (fastest modern toolchain)

```bash
# Install uv
curl -LsSf https://astral.sh/uv/install.sh | sh

# New project
uv init my-project
cd my-project
uv add fastapi httpx pydantic
uv add --dev pytest ruff mypy

# Run
uv run python main.py
uv run pytest
```

### pyproject.toml (standard)

```toml
[build-system]
requires = ["hatchling"]
build-backend = "hatchling.build"

[project]
name = "my-project"
version = "0.1.0"
requires-python = ">=3.11"
dependencies = [
    "httpx>=0.27",
    "pydantic>=2.0",
]

[project.optional-dependencies]
dev = ["pytest", "ruff", "mypy", "pytest-cov"]

[tool.ruff]
line-length = 100
target-version = "py311"

[tool.ruff.lint]
select = ["E", "F", "I", "UP", "B", "SIM"]
ignore = ["E501"]

[tool.mypy]
python_version = "3.11"
strict = true
ignore_missing_imports = true

[tool.pytest.ini_options]
testpaths = ["tests"]
addopts = "-v --tb=short"
```

### venv (classic, no uv)

```bash
python3.11 -m venv .venv
source .venv/bin/activate        # Linux/macOS
.venv\Scripts\activate           # Windows
pip install -e ".[dev]"
```

---

## Type Hints

Type hints are **mandatory** for all public functions and class attributes.

### Basics

```python
# Variables
name: str = "Alice"
count: int = 0
ratio: float = 0.5
active: bool = True

# Collections
from collections.abc import Sequence, Mapping, Iterator

names: list[str] = ["Alice", "Bob"]
scores: dict[str, int] = {"Alice": 95}
unique: set[int] = {1, 2, 3}
pair: tuple[str, int] = ("Alice", 30)
```

### Union, Optional, Literal

```python
from typing import Literal

# Modern union syntax (3.10+)
def process(val: str | int) -> str:
    return str(val)

# Optional = T | None
def find(name: str) -> User | None:
    ...

# Literal types
Status = Literal["pending", "approved", "rejected"]

def set_status(s: Status) -> None:
    ...
```

### TypedDict

```python
from typing import TypedDict, NotRequired

class UserDict(TypedDict):
    id: int
    name: str
    email: NotRequired[str]  # optional key
```

### Protocols (structural typing)

```python
from typing import Protocol, runtime_checkable

@runtime_checkable
class Closeable(Protocol):
    def close(self) -> None: ...

def cleanup(resource: Closeable) -> None:
    resource.close()

# Works with any object that has .close() — no inheritance needed
```

### TypeVar and generics

```python
from typing import TypeVar

T = TypeVar("T")

def first(items: list[T]) -> T | None:
    return items[0] if items else None

# Bounded TypeVar
Numeric = TypeVar("Numeric", int, float)

def double(x: Numeric) -> Numeric:
    return x * 2
```

### ParamSpec and Concatenate (decorators)

```python
from typing import ParamSpec, Callable, TypeVar
import functools

P = ParamSpec("P")
R = TypeVar("R")

def retry(times: int = 3) -> Callable[[Callable[P, R]], Callable[P, R]]:
    def decorator(fn: Callable[P, R]) -> Callable[P, R]:
        @functools.wraps(fn)
        def wrapper(*args: P.args, **kwargs: P.kwargs) -> R:
            for attempt in range(times):
                try:
                    return fn(*args, **kwargs)
                except Exception:
                    if attempt == times - 1:
                        raise
            raise RuntimeError("unreachable")
        return wrapper
    return decorator

@retry(times=3)
def fetch(url: str) -> bytes:
    ...
```

---

## Dataclasses and Pydantic

### dataclass (stdlib, fast, no validation)

```python
from dataclasses import dataclass, field

@dataclass
class Point:
    x: float
    y: float
    label: str = ""

@dataclass(frozen=True)   # immutable
class Config:
    host: str
    port: int = 8080
    tags: list[str] = field(default_factory=list)

    def url(self) -> str:
        return f"http://{self.host}:{self.port}"
```

### Pydantic v2 (validation + serialization)

```python
from pydantic import BaseModel, Field, field_validator, model_validator
from datetime import datetime

class User(BaseModel):
    id: int
    name: str = Field(min_length=1, max_length=100)
    email: str
    created_at: datetime = Field(default_factory=datetime.utcnow)

    @field_validator("email")
    @classmethod
    def validate_email(cls, v: str) -> str:
        if "@" not in v:
            raise ValueError("Invalid email")
        return v.lower()

# Parse from dict / JSON
user = User.model_validate({"id": 1, "name": "Alice", "email": "A@B.COM"})
print(user.email)       # a@b.com
print(user.model_dump()) # dict
print(user.model_dump_json()) # JSON string

# Nested models
class Order(BaseModel):
    user: User
    items: list[str]
    total: float = Field(ge=0)
```

### When to use which

| Use case | Tool |
|----------|------|
| Simple data containers, no validation | `@dataclass` |
| API request/response models | `Pydantic` |
| Config with env var parsing | `Pydantic BaseSettings` |
| Immutable value objects | `@dataclass(frozen=True)` |
| Performance-critical inner loop | `__slots__` class or named tuple |

---

## Error Handling

### Exception hierarchy

```python
# Define custom exceptions
class AppError(Exception):
    """Base error for this application."""

class NotFoundError(AppError):
    def __init__(self, resource: str, id: str | int) -> None:
        self.resource = resource
        self.id = id
        super().__init__(f"{resource} {id!r} not found")

class ValidationError(AppError):
    def __init__(self, field: str, message: str) -> None:
        self.field = field
        super().__init__(f"Validation error on '{field}': {message}")

# Usage
try:
    user = get_user(user_id)
except NotFoundError as e:
    logger.warning("Resource not found: %s %s", e.resource, e.id)
    raise HTTPException(status_code=404, detail=str(e)) from e
```

### Result pattern (no exceptions for expected failures)

```python
from dataclasses import dataclass
from typing import Generic, TypeVar

T = TypeVar("T")
E = TypeVar("E", bound=Exception)

@dataclass
class Ok(Generic[T]):
    value: T
    ok: bool = True

@dataclass
class Err(Generic[E]):
    error: E
    ok: bool = False

Result = Ok[T] | Err[E]

def parse_int(s: str) -> Result[int, ValueError]:
    try:
        return Ok(int(s))
    except ValueError as e:
        return Err(e)

result = parse_int("42")
if result.ok:
    print(result.value * 2)  # type narrowed to Ok
```

### Context managers for cleanup

```python
from contextlib import contextmanager, suppress

@contextmanager
def managed_connection(url: str):
    conn = connect(url)
    try:
        yield conn
    except Exception:
        conn.rollback()
        raise
    finally:
        conn.close()

# Suppress specific exceptions
with suppress(FileNotFoundError):
    os.remove("temp.txt")
```

---

## Functions & Patterns

### Clean function signatures

```python
# Bad: too many positional args
def create_user(name, email, age, role, active):
    ...

# Good: keyword-only after *
def create_user(
    name: str,
    email: str,
    *,                      # everything after is keyword-only
    age: int | None = None,
    role: str = "user",
    active: bool = True,
) -> User:
    ...
```

### Comprehensions vs loops

```python
# List comprehension
squares = [x**2 for x in range(10) if x % 2 == 0]

# Dict comprehension
word_lengths = {word: len(word) for word in words}

# Generator (lazy, memory-efficient)
total = sum(x**2 for x in range(10_000_000))

# Avoid nested comprehensions beyond 2 levels — use a loop
```

### Decorators

```python
import functools
import time

def timer(fn):
    @functools.wraps(fn)
    def wrapper(*args, **kwargs):
        start = time.perf_counter()
        result = fn(*args, **kwargs)
        elapsed = time.perf_counter() - start
        print(f"{fn.__name__} took {elapsed:.3f}s")
        return result
    return wrapper

# Parametrized decorator
def cache(maxsize: int = 128):
    def decorator(fn):
        return functools.lru_cache(maxsize=maxsize)(fn)
    return decorator
```

### Itertools and functools

```python
import itertools
import functools

# Chain iterables
all_items = list(itertools.chain(list1, list2, list3))

# Chunk a list
def chunks(lst, n):
    for i in range(0, len(lst), n):
        yield lst[i:i + n]

# Group by key
from itertools import groupby
data = sorted(users, key=lambda u: u.role)
for role, group in groupby(data, key=lambda u: u.role):
    print(role, list(group))

# Reduce
total = functools.reduce(lambda acc, x: acc + x, numbers, 0)

# Partial application
from functools import partial
double = partial(lambda x, n: x * n, n=2)
```

---

## Async Python

### Basics

```python
import asyncio
import httpx

async def fetch(url: str) -> dict:
    async with httpx.AsyncClient() as client:
        response = await client.get(url)
        response.raise_for_status()
        return response.json()

async def main() -> None:
    # Sequential
    data = await fetch("https://api.example.com/users")

    # Concurrent
    results = await asyncio.gather(
        fetch("https://api.example.com/users"),
        fetch("https://api.example.com/posts"),
    )

asyncio.run(main())
```

### Timeouts and cancellation

```python
async def fetch_with_timeout(url: str, timeout: float = 5.0) -> dict:
    async with asyncio.timeout(timeout):  # Python 3.11+
        return await fetch(url)

# Or with httpx timeout
async with httpx.AsyncClient(timeout=httpx.Timeout(5.0)) as client:
    response = await client.get(url)
```

### Async context managers and iterators

```python
class AsyncDB:
    async def __aenter__(self):
        await self.connect()
        return self

    async def __aexit__(self, *_):
        await self.disconnect()

async def stream_rows(query: str):
    async with AsyncDB() as db:
        async for row in db.execute(query):
            yield row

# Usage
async for row in stream_rows("SELECT * FROM users"):
    process(row)
```

### Common async mistakes

```python
# BAD: creates new client per request (slow)
async def fetch(url):
    async with httpx.AsyncClient() as client:  # don't put this in a loop
        return await client.get(url)

# GOOD: share client
client = httpx.AsyncClient()

async def fetch(url):
    return await client.get(url)

# BAD: blocking call in async context
async def process():
    time.sleep(1)          # blocks the event loop!
    data = open("f.txt").read()  # also blocks

# GOOD: use async equivalents
async def process():
    await asyncio.sleep(1)
    async with aiofiles.open("f.txt") as f:
        data = await f.read()
```

---

## FastAPI

```python
from fastapi import FastAPI, HTTPException, Depends, status
from pydantic import BaseModel

app = FastAPI()

class UserIn(BaseModel):
    name: str
    email: str

class UserOut(BaseModel):
    id: int
    name: str
    email: str

@app.post("/users", response_model=UserOut, status_code=status.HTTP_201_CREATED)
async def create_user(body: UserIn, db: DB = Depends(get_db)) -> UserOut:
    existing = await db.users.find_by_email(body.email)
    if existing:
        raise HTTPException(status_code=409, detail="Email already registered")
    user = await db.users.create(body.model_dump())
    return UserOut.model_validate(user)

# Dependency injection
async def get_db() -> AsyncIterator[DB]:
    async with DB.connect() as db:
        yield db
```

See `references/fastapi.md` for full patterns (auth, middleware, background tasks, testing).

---

## Testing with pytest

```python
# tests/test_user.py
import pytest
from unittest.mock import AsyncMock, patch

def test_parse_email_valid():
    result = parse_email("alice@example.com")
    assert result == "alice@example.com"

def test_parse_email_invalid():
    with pytest.raises(ValidationError, match="Invalid email"):
        parse_email("not-an-email")

# Parametrize
@pytest.mark.parametrize("input,expected", [
    ("ALICE@EXAMPLE.COM", "alice@example.com"),
    ("  bob@test.org  ", "bob@test.org"),
])
def test_normalize_email(input, expected):
    assert normalize_email(input) == expected

# Fixtures
@pytest.fixture
def sample_user():
    return User(id=1, name="Alice", email="alice@example.com")

# Async test
@pytest.mark.asyncio
async def test_fetch_user(sample_user):
    with patch("myapp.db.find_user", return_value=sample_user):
        result = await fetch_user(1)
        assert result.name == "Alice"
```

See `references/testing.md` for fixtures, mocking, factories, coverage.

---

## Debugging Common Errors

### TypeError: unsupported operand / unexpected type

```python
# Symptom: TypeError: can only concatenate str (not "int") to str
name = "User #" + user_id   # user_id is int

# Fix: explicit conversion
name = f"User #{user_id}"
name = "User #" + str(user_id)
```

### AttributeError: 'NoneType' has no attribute '...'

```python
# Symptom: AttributeError: 'NoneType' object has no attribute 'name'
user = db.find(id)
print(user.name)  # user might be None

# Fix: guard
if user is None:
    raise NotFoundError("User", id)
print(user.name)

# Or use walrus operator
if user := db.find(id):
    print(user.name)
```

### RecursionError / stack overflow

```python
# Symptom: RecursionError: maximum recursion depth exceeded
# Fix: add base case, or convert to iterative with a stack
import sys
sys.setrecursionlimit(10_000)  # last resort
```

### ImportError / ModuleNotFoundError

```python
# Symptom: ModuleNotFoundError: No module named 'myapp'
# Fix 1: install the package
pip install myapp

# Fix 2: for local packages, install in editable mode
pip install -e .

# Fix 3: check PYTHONPATH
import sys; print(sys.path)
```

### RuntimeError: no running event loop

```python
# Symptom: in sync code calling async function
asyncio.get_event_loop().run_until_complete(my_async_fn())  # deprecated

# Fix
asyncio.run(my_async_fn())  # Python 3.11+
```

### Common type errors (mypy / pyright)

```python
# error: Item "None" of "X | None" has no attribute "Y"
user: User | None = get_user()
user.name  # error

# Fix: narrow first
assert user is not None
user.name  # ok

# OR
if user:
    user.name

# error: Argument 1 to "fn" has incompatible type "str | None"; expected "str"
# Fix: provide default
name = raw_name or "default"
fn(name)
```

---

## Code Quality Checklist (review mode)

When reviewing Python code, check in order:

1. **Type hints** — all public functions annotated? No bare `Any`?
2. **None handling** — every `| None` return value handled before use?
3. **Exception handling** — specific exceptions caught, not bare `except:`?
4. **Resource cleanup** — files/connections closed? Using `with`?
5. **Async correctness** — no blocking calls in async functions?
6. **Mutation** — mutable default args? (`def fn(x=[])` is a bug)
7. **Import order** — stdlib → third-party → local (ruff fixes this)
8. **Dead code** — unused imports, variables, functions?
9. **Magic values** — hardcoded strings/numbers → constants?
10. **Test coverage** — happy path + error path covered?

---

## Anti-patterns

| Anti-pattern | Problem | Fix |
|---|---|---|
| `except:` or `except Exception:` | Hides bugs | Catch specific exceptions |
| Mutable default arg `def f(x=[])` | Shared across calls | Use `None` + `if x is None: x = []` |
| `import *` | Pollutes namespace | Explicit imports |
| Bare `type: ignore` | Hides real errors | Fix the type or narrow |
| `global` / `nonlocal` overuse | Hard to reason | Return values instead |
| `os.system()` for subprocesses | No error handling | Use `subprocess.run()` |
| String concatenation in loops | O(n²) | Use `"".join(parts)` |
| Deep nesting (>3 levels) | Hard to read | Extract functions, use early return |
| `print()` for debugging in production | Not structured | Use `logging` module |

---

## Reference Files

Load on demand:

- `references/stdlib.md` — pathlib, logging, subprocess, dataclasses, collections, contextlib
- `references/data.md` — pandas, numpy, CSV/JSON processing, generators for large files
- `references/fastapi.md` — full FastAPI patterns: auth, middleware, DI, background tasks, testing
- `references/testing.md` — pytest fixtures, mocking, factories, parametrize, async tests, coverage
- `references/packaging.md` — pyproject.toml, uv, Docker, CI/CD, publishing to PyPI