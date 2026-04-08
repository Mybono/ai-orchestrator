# Python Packaging & CI Reference

> Load when: user asks about pyproject.toml, packaging, Docker, CI/CD, publishing to PyPI, or deploying Python apps.

## pyproject.toml — complete template

```toml
[build-system]
requires = ["hatchling"]
build-backend = "hatchling.build"

[project]
name = "my-package"
version = "0.1.0"
description = "Short description"
readme = "README.md"
license = { text = "MIT" }
authors = [{ name = "Name", email = "name@example.com" }]
requires-python = ">=3.11"
keywords = ["keyword1", "keyword2"]
classifiers = [
    "Programming Language :: Python :: 3.11",
    "License :: OSI Approved :: MIT License",
]
dependencies = [
    "httpx>=0.27",
    "pydantic>=2.0",
]

[project.optional-dependencies]
dev = ["pytest", "pytest-cov", "pytest-asyncio", "ruff", "mypy"]
api = ["fastapi", "uvicorn[standard]"]

[project.scripts]
my-cli = "myapp.cli:main"

[tool.hatch.build.targets.wheel]
packages = ["src/myapp"]

[tool.ruff]
line-length = 100
target-version = "py311"
src = ["src", "tests"]

[tool.ruff.lint]
select = ["E", "F", "I", "UP", "B", "SIM", "ANN"]
ignore = ["ANN101", "ANN102"]

[tool.mypy]
python_version = "3.11"
strict = true
ignore_missing_imports = true
exclude = ["tests/"]

[tool.pytest.ini_options]
testpaths = ["tests"]
asyncio_mode = "auto"
addopts = "-v --tb=short --cov=myapp --cov-report=term-missing"

[tool.coverage.run]
source = ["myapp"]
omit = ["*/tests/*"]
```

## Docker

```dockerfile
# Dockerfile
FROM python:3.11-slim AS base
WORKDIR /app
ENV PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1

# Dependencies layer (cached separately)
FROM base AS deps
COPY pyproject.toml .
RUN pip install --no-cache-dir -e ".[api]"

# Final image
FROM deps AS final
COPY src/ ./src/
EXPOSE 8000
CMD ["uvicorn", "myapp.main:app", "--host", "0.0.0.0", "--port", "8000"]
```

```dockerfile
# With uv (faster builds)
FROM python:3.11-slim
COPY --from=ghcr.io/astral-sh/uv:latest /uv /usr/local/bin/uv
WORKDIR /app
COPY pyproject.toml uv.lock ./
RUN uv sync --frozen --no-dev
COPY src/ ./src/
CMD ["uv", "run", "uvicorn", "myapp.main:app", "--host", "0.0.0.0", "--port", "8000"]
```

## GitHub Actions CI

```yaml
# .github/workflows/ci.yml
name: CI

on:
  push:
    branches: [main]
  pull_request:

jobs:
  test:
    runs-on: ubuntu-latest
    strategy:
      matrix:
        python-version: ["3.11", "3.12"]

    steps:
      - uses: actions/checkout@v4

      - name: Install uv
        uses: astral-sh/setup-uv@v3

      - name: Set up Python ${{ matrix.python-version }}
        run: uv python install ${{ matrix.python-version }}

      - name: Install dependencies
        run: uv sync --all-extras --dev

      - name: Lint
        run: uv run ruff check .

      - name: Type check
        run: uv run mypy src/

      - name: Test
        run: uv run pytest --cov --cov-fail-under=80

      - name: Upload coverage
        uses: codecov/codecov-action@v4
        with:
          token: ${{ secrets.CODECOV_TOKEN }}
```

## Publish to PyPI

```yaml
# .github/workflows/release.yml
name: Release

on:
  push:
    tags: ["v*"]

jobs:
  publish:
    runs-on: ubuntu-latest
    environment: pypi
    permissions:
      id-token: write  # for trusted publishing

    steps:
      - uses: actions/checkout@v4
      - uses: astral-sh/setup-uv@v3
      - run: uv build
      - uses: pypa/gh-action-pypi-publish@release/v1
```

## Makefile for common tasks

```makefile
.PHONY: install dev test lint typecheck clean

install:
 uv sync

dev:
 uv run uvicorn myapp.main:app --reload

test:
 uv run pytest

lint:
 uv run ruff check . --fix
 uv run ruff format .

typecheck:
 uv run mypy src/

ci: lint typecheck test

clean:
 rm -rf dist/ .mypy_cache/ .ruff_cache/ .pytest_cache/ htmlcov/
 find . -type d -name "__pycache__" -exec rm -rf {} +
```

## .env and secrets management

```bash
# .env (never commit)
DATABASE_URL=postgresql://user:pass@localhost/mydb
API_KEY=secret123
DEBUG=false

# .env.example (commit this)
DATABASE_URL=postgresql://user:pass@localhost/mydb
API_KEY=your-api-key-here
DEBUG=false
```

```python
# Load in dev with python-dotenv
from dotenv import load_dotenv
load_dotenv()  # reads .env into os.environ

# Or via pydantic-settings (auto-loads .env)
from pydantic_settings import BaseSettings

class Settings(BaseSettings):
    database_url: str
    api_key: str
    debug: bool = False

    model_config = {"env_file": ".env"}
```

## src layout (recommended)

```text
my-package/
├── src/
│   └── myapp/
│       ├── __init__.py
│       ├── main.py
│       └── ...
├── tests/
│   ├── conftest.py
│   └── test_main.py
├── pyproject.toml
├── README.md
├── .env.example
└── .gitignore
```

Advantages of `src/` layout: prevents accidentally importing from source instead of installed package, cleaner separation.
