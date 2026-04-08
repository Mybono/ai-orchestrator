Refactor Python code for clarity, performance, and Pythonic idioms.

Load the following expertise before starting:

- [python-code-standarts](../../../skills/python-code-standarts.md)

## Process

1. Analyze target Python code for PEP 8 compliance and anti-patterns (e.g., non-idiomatic loops).
2. Apply Pythionic refactors:
   - Convert list/dict comprehensions.
   - Use `pathlib` over `os.path`.
   - Use `contextlib` or `with` statements for resource management.
   - Extract logic into dataclasses or named tuples for clarity.
   - Optimize imports and docstring formatting.
3. Verify changes by running mypy or pytest if available.

## Rules

- Strictly follow [python-code-standarts](../../../skills/python-code-standarts.md).
- Prioritize Readability (Zen of Python).
- Use moderne Python features (f-strings, Walrus operator where appropriate).
