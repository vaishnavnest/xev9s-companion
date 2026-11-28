import os

from dotenv import load_dotenv
from pymongo import MongoClient
from pymongo.errors import PyMongoError

load_dotenv()

MONGODB_URI = os.getenv("MONGODB_URI")
MONGODB_DATABASE = os.getenv("MONGODB_DATABASE")

client = None
database = None


def connect_to_database():
    global client, database

    if not MONGODB_URI or not MONGODB_DATABASE:
        raise ValueError("MongoDB environment variables are missing")

    if client is not None and database is not None:
        return database

    new_client = MongoClient(
        MONGODB_URI,
        serverSelectionTimeoutMS=5000,
        tz_aware=True,
    )

    try:
        new_client.admin.command("ping")
        database = new_client[MONGODB_DATABASE]
        client = new_client
        return database

    except PyMongoError:
        new_client.close()
        raise


def close_database_connection():
    global client, database

    if client is not None:
        client.close()

    client = None
    database = None
