# Python Testing Reference

> Load when: user asks about pytest, fixtures, mocking, parametrize, coverage, async tests, or test factories.

## pytest basics

```python
# tests/test_user.py
import pytest

def test_basic_assertion():
    assert 1 + 1 == 2

def test_raises():
    with pytest.raises(ValueError, match="Invalid"):
        parse("bad input")

def test_approx():
    assert 0.1 + 0.2 == pytest.approx(0.3)

# Mark tests
@pytest.mark.slow
def test_heavy():
    ...

@pytest.mark.skip(reason="not implemented yet")
def test_future():
    ...
```

## Fixtures

```python
import pytest
from myapp.models import User
from myapp.db import DB

# Simple fixture
@pytest.fixture
def sample_user() -> User:
    return User(id=1, name="Alice", email="alice@example.com")

# Fixture with teardown
@pytest.fixture
def tmp_file(tmp_path):
    f = tmp_path / "test.txt"
    f.write_text("hello")
    yield f
    # teardown (optional — tmp_path cleaned up automatically)

# Fixture scope
@pytest.fixture(scope="session")
def db_connection():
    conn = DB.connect(":memory:")
    conn.create_tables()
    yield conn
    conn.close()

# Async fixture
@pytest.fixture
async def async_client():
    from httpx import AsyncClient, ASGITransport
    from myapi.main import app
    async with AsyncClient(transport=ASGITransport(app=app), base_url="http://test") as c:
        yield c

# Fixture with params
@pytest.fixture(params=["sqlite", "postgres"])
def db(request):
    return DB.connect(request.param)
```

## Parametrize

```python
@pytest.mark.parametrize("email,expected", [
    ("alice@example.com", True),
    ("not-an-email", False),
    ("@missing-local.com", False),
    ("missing-domain@", False),
])
def test_validate_email(email: str, expected: bool):
    assert validate_email(email) == expected

# Multiple parameters
@pytest.mark.parametrize("a,b,expected", [
    (1, 2, 3),
    (0, 0, 0),
    (-1, 1, 0),
])
def test_add(a: int, b: int, expected: int):
    assert add(a, b) == expected

# Parametrize with IDs
@pytest.mark.parametrize("status", ["pending", "active", "disabled"], ids=lambda s: s)
def test_user_status(status: str):
    user = User(status=status)
    assert user.status == status
```

## Mocking

```python
from unittest.mock import patch, MagicMock, AsyncMock, call

# Patch module-level function
def test_fetch(monkeypatch):
    monkeypatch.setattr("myapp.api.requests.get", lambda url: MagicMock(json=lambda: {"id": 1}))
    result = fetch_user(1)
    assert result["id"] == 1

# Patch with context manager
def test_send_email():
    with patch("myapp.email.send_smtp") as mock_send:
        send_welcome_email("alice@example.com")
        mock_send.assert_called_once_with(
            to="alice@example.com",
            subject="Welcome!",
        )

# AsyncMock for async functions
@pytest.mark.asyncio
async def test_async_fetch():
    with patch("myapp.db.users.get", new_callable=AsyncMock) as mock_get:
        mock_get.return_value = User(id=1, name="Alice", email="a@b.com")
        result = await get_user(1)
        assert result.name == "Alice"
        mock_get.assert_awaited_once_with(1)

# Mock with side_effect (exception or sequence)
def test_retry():
    with patch("myapp.api.call") as mock_call:
        mock_call.side_effect = [
            ConnectionError("timeout"),
            ConnectionError("timeout"),
            {"status": "ok"},  # succeeds on 3rd attempt
        ]
        result = call_with_retry()
        assert result == {"status": "ok"}
        assert mock_call.call_count == 3
```

## Test factories

```python
from typing import Any
import random
import string

def make_user(**overrides: Any) -> dict:
    """Create a test user dict with sensible defaults."""
    suffix = "".join(random.choices(string.ascii_lowercase, k=6))
    defaults = {
        "name": f"User {suffix}",
        "email": f"user_{suffix}@test.com",
        "role": "user",
        "active": True,
    }
    return {**defaults, **overrides}

# Usage
def test_admin_can_delete():
    user = make_user(role="admin")
    ...

def test_inactive_user_blocked():
    user = make_user(active=False)
    ...

# Or use factory-boy / polyfactory
from polyfactory.factories.pydantic_factory import ModelFactory

class UserFactory(ModelFactory):
    __model__ = User

user = UserFactory.build()
users = UserFactory.batch(10)
admin = UserFactory.build(role="admin")
```

## Async tests

```python
# Install: pip install pytest-asyncio
# conftest.py
import pytest

@pytest.fixture(scope="session")
def event_loop_policy():
    import asyncio
    return asyncio.DefaultEventLoopPolicy()

# Or set globally in pyproject.toml:
# [tool.pytest.ini_options]
# asyncio_mode = "auto"

@pytest.mark.asyncio
async def test_async_operation():
    result = await my_async_function()
    assert result == expected

# Test timeout
@pytest.mark.asyncio
@pytest.mark.timeout(5)
async def test_does_not_hang():
    result = await operation_that_should_be_fast()
    assert result is not None
```

## Coverage

```bash
# Run with coverage
pytest --cov=myapp --cov-report=term-missing --cov-report=html

# Fail if below threshold
pytest --cov=myapp --cov-fail-under=80
```

```toml
# pyproject.toml
[tool.coverage.run]
source = ["myapp"]
omit = ["*/tests/*", "*/migrations/*"]

[tool.coverage.report]
exclude_lines = [
    "pragma: no cover",
    "if TYPE_CHECKING:",
    "raise NotImplementedError",
]
```

## conftest.py patterns

```python
# tests/conftest.py
import pytest
from pathlib import Path

# Make fixtures available to all tests automatically
@pytest.fixture(autouse=True)
def reset_env(monkeypatch):
    """Ensure clean env vars for each test."""
    monkeypatch.delenv("DATABASE_URL", raising=False)
    monkeypatch.setenv("DATABASE_URL", "sqlite:///:memory:")

# Shared path fixtures
@pytest.fixture
def data_dir() -> Path:
    return Path(__file__).parent / "data"

@pytest.fixture
def sample_csv(data_dir: Path) -> Path:
    return data_dir / "sample.csv"
```