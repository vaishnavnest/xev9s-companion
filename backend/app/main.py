
from fastapi import FastAPI

app = FastAPI(
    title="XEV 9S Backend",
    description="Backend API for the XEV 9S connected vehicle platform",
    version="1.0.0"
)


@app.get("/")
def root():
    return {
        "message": "XEV 9S Backend is running"
    }


@app.get("/health")
def health_check():
    return {
        "status": "healthy"
    }
