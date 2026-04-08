# Python stdlib Reference

> Load when: user asks about pathlib, logging, subprocess, collections, contextlib, json, csv, or standard library modules.

## pathlib — file system

```python
from pathlib import Path

p = Path("/home/user/project")

# Build paths
config = p / "config" / "settings.toml"

# Read / write
text = config.read_text(encoding="utf-8")
config.write_text("key=value", encoding="utf-8")
data = config.read_bytes()

# Check existence
if config.exists():
    ...
if config.is_file():
    ...
if config.is_dir():
    ...

# Iterate directory
for f in p.glob("**/*.py"):      # recursive
    print(f)
for f in p.glob("*.json"):       # non-recursive
    print(f)

# File metadata
stat = config.stat()
size = stat.st_size
mtime = stat.st_mtime

# Create / delete
(p / "output").mkdir(parents=True, exist_ok=True)
config.unlink(missing_ok=True)  # delete file

# Common patterns
script_dir = Path(__file__).parent
project_root = script_dir.parent
```

## logging

```python
import logging
import sys

# Basic setup (scripts)
logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s [%(levelname)s] %(name)s: %(message)s",
    handlers=[logging.StreamHandler(sys.stdout)],
)

# Module-level logger (use in every module)
logger = logging.getLogger(__name__)

logger.debug("Debug: %s", value)      # use %s, not f-string (lazy eval)
logger.info("Processing %d items", n)
logger.warning("Retry %d/%d", attempt, max_attempts)
logger.error("Failed: %s", exc)
logger.exception("Unexpected error")  # includes traceback

# File handler
handler = logging.FileHandler("app.log", encoding="utf-8")
handler.setFormatter(logging.Formatter("%(asctime)s %(levelname)s %(message)s"))
logging.getLogger().addHandler(handler)

# Structured logging (production)
import json

class JsonFormatter(logging.Formatter):
    def format(self, record: logging.LogRecord) -> str:
        return json.dumps({
            "ts": self.formatTime(record),
            "level": record.levelname,
            "logger": record.name,
            "msg": record.getMessage(),
        })
```

## subprocess

```python
import subprocess

# Simple: run and check
result = subprocess.run(
    ["git", "status"],
    capture_output=True,
    text=True,
    check=True,          # raises CalledProcessError on non-zero exit
)
print(result.stdout)

# With timeout
try:
    result = subprocess.run(
        ["./build.sh"],
        capture_output=True,
        text=True,
        check=True,
        timeout=60,
    )
except subprocess.TimeoutExpired:
    logger.error("Build timed out")
except subprocess.CalledProcessError as e:
    logger.error("Build failed (exit %d):\n%s", e.returncode, e.stderr)
    raise

# Stream output in real time
with subprocess.Popen(
    ["./long_script.sh"],
    stdout=subprocess.PIPE,
    stderr=subprocess.STDOUT,
    text=True,
) as proc:
    for line in proc.stdout:
        print(line, end="")
    proc.wait()
    if proc.returncode != 0:
        raise subprocess.CalledProcessError(proc.returncode, proc.args)
```

## collections

```python
from collections import defaultdict, Counter, deque, OrderedDict
from collections import namedtuple

# defaultdict: no KeyError on missing key
word_count: defaultdict[str, int] = defaultdict(int)
for word in words:
    word_count[word] += 1

graph: defaultdict[str, list[str]] = defaultdict(list)
graph["a"].append("b")

# Counter: count hashable objects
counter = Counter(["a", "b", "a", "c", "a"])
counter.most_common(2)  # [("a", 3), ("b", 1)]

# deque: O(1) append/pop from both ends
queue: deque[int] = deque(maxlen=100)
queue.appendleft(0)
queue.append(1)
queue.popleft()

# namedtuple: lightweight immutable record
Point = namedtuple("Point", ["x", "y"])
p = Point(1.0, 2.0)
print(p.x, p.y)

# Or typed version
from typing import NamedTuple

class Point(NamedTuple):
    x: float
    y: float
    label: str = ""
```

## contextlib

```python
from contextlib import contextmanager, asynccontextmanager, suppress, ExitStack

# Sync context manager
@contextmanager
def temp_dir():
    path = Path(tempfile.mkdtemp())
    try:
        yield path
    finally:
        shutil.rmtree(path, ignore_errors=True)

# Async context manager
@asynccontextmanager
async def lifespan(app):
    db = await DB.connect()
    yield {"db": db}
    await db.disconnect()

# Suppress specific exception
with suppress(FileNotFoundError, PermissionError):
    os.remove("temp.txt")

# Combine multiple context managers dynamically
with ExitStack() as stack:
    files = [stack.enter_context(open(f)) for f in filenames]
    # all files closed on exit
```

## json / csv

```python
import json
import csv
from pathlib import Path

# JSON
data = json.loads('{"key": "value"}')
text = json.dumps(data, indent=2, ensure_ascii=False, default=str)

Path("out.json").write_text(text, encoding="utf-8")
data = json.loads(Path("out.json").read_text(encoding="utf-8"))

# CSV read
with open("data.csv", newline="", encoding="utf-8") as f:
    reader = csv.DictReader(f)
    rows = list(reader)  # list of dicts

# CSV write
with open("out.csv", "w", newline="", encoding="utf-8") as f:
    writer = csv.DictWriter(f, fieldnames=["name", "email"])
    writer.writeheader()
    writer.writerows([{"name": "Alice", "email": "a@b.com"}])
```

## argparse (CLI scripts)

```python
import argparse

def make_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(
        description="Process files",
        formatter_class=argparse.RawDescriptionHelpFormatter,
    )
    parser.add_argument("input", type=Path, help="Input file")
    parser.add_argument("-o", "--output", type=Path, default=Path("out.json"))
    parser.add_argument("-v", "--verbose", action="store_true")
    parser.add_argument("--workers", type=int, default=4, metavar="N")
    return parser

def main() -> None:
    args = make_parser().parse_args()
    if args.verbose:
        logging.basicConfig(level=logging.DEBUG)
    process(args.input, args.output, workers=args.workers)

if __name__ == "__main__":
    main()
```

## tempfile / shutil

```python
import tempfile
import shutil

# Temp file (auto-deleted)
with tempfile.NamedTemporaryFile(suffix=".json", delete=True) as f:
    f.write(b'{"key": "val"}')
    f.flush()
    process(f.name)

# Temp directory
with tempfile.TemporaryDirectory() as tmpdir:
    work = Path(tmpdir)
    (work / "data.txt").write_text("hello")

# shutil: copy, move, archive
shutil.copy2("src.txt", "dst.txt")         # copy with metadata
shutil.copytree("src/", "dst/")            # recursive copy
shutil.move("old.txt", "new.txt")
shutil.rmtree("build/", ignore_errors=True)
shutil.make_archive("archive", "zip", "dist/")  # creates archive.zip
```