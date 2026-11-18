from contextlib import asynccontextmanager

from backend.app.core.database import (
    close_database_connection,
    connect_to_database,
)
from backend.app.core.indexes import ensure_database_indexes
from backend.app.routes.auth import router as auth_router
from fastapi import FastAPI, HTTPException, Request
from pymongo.errors import PyMongoError


@asynccontextmanager
async def lifespan(app: FastAPI):
    app.state.database = connect_to_database()

    try:
        ensure_database_indexes(app.state.database)
        yield
    finally:
        close_database_connection()


app = FastAPI(
    title="XEV 9S Backend",
    description="Backend API for the XEV 9S connected vehicle platform",
    version="1.0.0",
    lifespan=lifespan,
)

app.include_router(auth_router)


@app.get("/")
def root():
    return {"message": "XEV 9S Backend is running"}


@app.get("/health")
def health_check():
    return {"status": "healthy"}


@app.get("/health/database")
def database_health_check(request: Request):
    try:
        request.app.state.database.command("ping")
        return {"database": "connected"}
    except PyMongoError:
        raise HTTPException(
            status_code=503,
            detail="Database connection unavailable",
        )
