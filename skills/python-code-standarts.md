# Python Code Quality standarts

## General Principles

- Prefer readability over cleverness
- Follow PEP 8 and PEP 20 (Zen of Python)
- Code should be self-documenting
- Avoid premature optimization
- Keep functions and classes small and focused
- Follow SOLID principles when applicable

## Naming

- `snake_case` for variables and functions
- `PascalCase` for classes
- `UPPER_CASE` for constants
- Avoid abbreviations unless widely known (`id`, `url`)

## Formatting

- Max line length: 88 chars (Black standard)
- 4 spaces indentation
- Trailing commas in multiline structures

## Typing

Always use type hints. Prefer built-in generics:

```python
def get_user(user_id: int) -> dict[str, str]:
    ...
```

Use `TypedDict`, `Protocol`, or `dataclass` when helpful.

## Imports

Group in order: stdlib → third-party → local. No wildcard imports.

```python
import os
import sys

import requests

from myapp.services import user_service
```

## Functions

- Max ~20–30 lines
- Single responsibility
- Avoid side effects where possible
- Prefer explicit arguments over `**kwargs`

```python
def calculate_total(price: float, tax: float) -> float:
    return price * (1 + tax)
```

## Classes

Use classes only when needed. Prefer dataclasses for simple data containers:

```python
from dataclasses import dataclass

@dataclass
class User:
    id: int
    name: str
```

## Error Handling

Catch specific exceptions. Never use bare `except`. Avoid swallowing errors silently.

```python
try:
    value = int(data)
except ValueError as e:
    raise InvalidInputError("Invalid number") from e
```

## Testing

- Use `pytest`
- Write small, isolated unit tests
- Prefer testing behavior, not implementation

## Clean Code

- Remove dead code
- Avoid duplication (DRY)
- Use meaningful variable names
- Replace magic numbers with constants

## Performance

- Optimize only when necessary
- Use generators for large data
- Avoid unnecessary loops

## Security

- Never hardcode secrets
- Validate all external input
- Use environment variables for config

## Tooling

- `black` — formatting
- `ruff` — linting
- `mypy` — type checking
- `pytest` — testing

## Documentation

Use docstrings for public APIs (Google style):

```python
def fetch_user(user_id: int) -> User:
    """Fetch user by ID.

    Args:
        user_id: Unique user identifier.

    Returns:
        User object.
    """
```

## Anti-Patterns

- God objects / massive classes
- Deep nesting (>3 levels)
- Hidden side effects
- Overuse of globals
- Copy-paste programming

## Definition of Done

- Code is readable and clean
- Fully typed
- Covered by tests
- Linted and formatted
- No obvious bugs or edge cases ignored
