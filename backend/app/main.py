
from contextlib import asynccontextmanager

from fastapi import FastAPI, HTTPException, Request
from pymongo.errors import PyMongoError

from backend.app.core.database import (
    connect_to_database,
    close_database_connection,
)


@asynccontextmanager
async def lifespan(app: FastAPI):
    app.state.database = connect_to_database()

    try:
        yield
    finally:
        close_database_connection()


app = FastAPI(
    title="XEV 9S Backend",
    description="Backend API for the XEV 9S connected vehicle platform",
    version="1.0.0",
    lifespan=lifespan,
)


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
