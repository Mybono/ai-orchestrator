# FastAPI Reference

> Load when: user asks about FastAPI, REST API, async API, dependency injection, middleware, auth, or background tasks.

## App structure

```
myapi/
├── main.py              # app factory + lifespan
├── config.py            # pydantic settings
├── dependencies.py      # shared DI functions
├── routers/
│   ├── users.py
│   └── auth.py
├── models/
│   ├── user.py          # Pydantic schemas
│   └── common.py
├── services/
│   └── user_service.py  # business logic
└── tests/
    ├── conftest.py
    └── test_users.py
```

## App factory with lifespan

```python
from contextlib import asynccontextmanager
from fastapi import FastAPI

@asynccontextmanager
async def lifespan(app: FastAPI):
    # Startup
    app.state.db = await DB.connect()
    app.state.cache = await Cache.connect()
    yield
    # Shutdown
    await app.state.db.disconnect()
    await app.state.cache.disconnect()

app = FastAPI(
    title="My API",
    version="1.0.0",
    lifespan=lifespan,
)

app.include_router(users_router, prefix="/users", tags=["users"])
app.include_router(auth_router, prefix="/auth", tags=["auth"])
```

## Request / Response models

```python
from pydantic import BaseModel, Field
from datetime import datetime

class UserIn(BaseModel):
    name: str = Field(min_length=1, max_length=100)
    email: str
    role: Literal["user", "admin"] = "user"

class UserOut(BaseModel):
    id: int
    name: str
    email: str
    created_at: datetime

class ErrorResponse(BaseModel):
    detail: str
    code: str = "error"

class PaginatedResponse(BaseModel, Generic[T]):
    items: list[T]
    total: int
    page: int
    page_size: int
```

## Router patterns

```python
from fastapi import APIRouter, HTTPException, Depends, status, Query

router = APIRouter()

@router.get("/", response_model=PaginatedResponse[UserOut])
async def list_users(
    page: int = Query(default=1, ge=1),
    page_size: int = Query(default=20, ge=1, le=100),
    db: DB = Depends(get_db),
) -> PaginatedResponse[UserOut]:
    users, total = await db.users.paginate(page=page, size=page_size)
    return PaginatedResponse(
        items=[UserOut.model_validate(u) for u in users],
        total=total, page=page, page_size=page_size,
    )

@router.get("/{user_id}", response_model=UserOut)
async def get_user(user_id: int, db: DB = Depends(get_db)) -> UserOut:
    user = await db.users.get(user_id)
    if not user:
        raise HTTPException(status_code=404, detail=f"User {user_id} not found")
    return UserOut.model_validate(user)

@router.post("/", response_model=UserOut, status_code=status.HTTP_201_CREATED)
async def create_user(body: UserIn, db: DB = Depends(get_db)) -> UserOut:
    if await db.users.find_by_email(body.email):
        raise HTTPException(status_code=409, detail="Email already registered")
    user = await db.users.create(body.model_dump())
    return UserOut.model_validate(user)

@router.delete("/{user_id}", status_code=status.HTTP_204_NO_CONTENT)
async def delete_user(user_id: int, db: DB = Depends(get_db)) -> None:
    if not await db.users.delete(user_id):
        raise HTTPException(status_code=404, detail="User not found")
```

## Dependency injection

```python
from fastapi import Depends, Request
from typing import AsyncIterator, Annotated

async def get_db(request: Request) -> AsyncIterator[DB]:
    async with request.app.state.db.session() as session:
        yield session

# Reusable annotated type
DB_DEP = Annotated[DB, Depends(get_db)]

# Auth dependency
async def get_current_user(
    token: str = Depends(oauth2_scheme),
    db: DB_DEP = None,
) -> User:
    payload = verify_jwt(token)
    user = await db.users.get(payload["sub"])
    if not user:
        raise HTTPException(status_code=401, detail="Invalid token")
    return user

CurrentUser = Annotated[User, Depends(get_current_user)]

# Use in router
@router.get("/me", response_model=UserOut)
async def get_me(user: CurrentUser) -> UserOut:
    return UserOut.model_validate(user)
```

## Middleware

```python
import time
import uuid
from fastapi import Request, Response

@app.middleware("http")
async def add_request_id(request: Request, call_next):
    request_id = str(uuid.uuid4())
    request.state.request_id = request_id
    start = time.perf_counter()
    response: Response = await call_next(request)
    elapsed = time.perf_counter() - start
    response.headers["X-Request-ID"] = request_id
    response.headers["X-Response-Time"] = f"{elapsed:.3f}s"
    return response

# CORS
from fastapi.middleware.cors import CORSMiddleware

app.add_middleware(
    CORSMiddleware,
    allow_origins=["https://myapp.com"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)
```

## Background tasks

```python
from fastapi import BackgroundTasks

async def send_welcome_email(email: str, name: str) -> None:
    await mailer.send(to=email, subject="Welcome!", body=f"Hi {name}!")

@router.post("/users", response_model=UserOut, status_code=201)
async def create_user(
    body: UserIn,
    background_tasks: BackgroundTasks,
    db: DB_DEP = None,
) -> UserOut:
    user = await db.users.create(body.model_dump())
    background_tasks.add_task(send_welcome_email, user.email, user.name)
    return UserOut.model_validate(user)
```

## Exception handlers

```python
from fastapi import Request
from fastapi.responses import JSONResponse

@app.exception_handler(NotFoundError)
async def not_found_handler(request: Request, exc: NotFoundError) -> JSONResponse:
    return JSONResponse(status_code=404, content={"detail": str(exc), "code": "NOT_FOUND"})

@app.exception_handler(ValidationError)
async def validation_handler(request: Request, exc: ValidationError) -> JSONResponse:
    return JSONResponse(status_code=400, content={"detail": str(exc), "code": "VALIDATION_ERROR"})
```

## Testing FastAPI

```python
import pytest
from httpx import AsyncClient, ASGITransport
from myapi.main import app

@pytest.fixture
async def client():
    async with AsyncClient(transport=ASGITransport(app=app), base_url="http://test") as c:
        yield c

@pytest.mark.asyncio
async def test_create_user(client: AsyncClient):
    response = await client.post("/users", json={"name": "Alice", "email": "a@b.com"})
    assert response.status_code == 201
    data = response.json()
    assert data["name"] == "Alice"

@pytest.mark.asyncio
async def test_duplicate_email(client: AsyncClient):
    payload = {"name": "Alice", "email": "a@b.com"}
    await client.post("/users", json=payload)
    response = await client.post("/users", json=payload)
    assert response.status_code == 409
```
