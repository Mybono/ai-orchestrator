Add comprehensive type hints to Python code for better IDE support and type safety.

Load the following expertise before starting:

- [python-code-standarts](../../../skills/python-code-standarts.md)

## Process

1. Scan files for functions and classes lacking type annotations.
2. Infer types from:
   - Variable usage and method calls.
   - Pydantic models or dataclasses.
   - External library documentation.
3. Apply type hints using the `typing` module (or built-in types for Python 3.10+).
4. Add `TypeAlias`, `Generic`, or `Union` where appropriate for complex structures.
5. Verify with `mypy --strict`.

## Rules

- Favor modern type syntax (e.g., `list[str]` over `List[str]`).
- Do not use `Any` unless absolutely necessary and documented.
- Annotate `*args` and `**kwargs` properly.
- Ensure all public APIs have return type annotations.
