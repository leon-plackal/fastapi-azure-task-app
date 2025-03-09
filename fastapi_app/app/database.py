from sqlalchemy import create_engine
from sqlalchemy.ext.declarative import declarative_base
from sqlalchemy.orm import sessionmaker
from app.config import settings
import urllib.parse

# Construct the connection string for Azure SQL Database
params = urllib.parse.quote_plus(
    f"Driver={{{settings.DB_DRIVER}}};Server=tcp:{settings.DB_SERVER},1433;"
    f"Database={settings.DB_NAME};Uid={settings.DB_USER};"
    f"Pwd={settings.DB_PASSWORD};Encrypt=yes;TrustServerCertificate=no;"
    f"Connection Timeout=30;"
)

SQLALCHEMY_DATABASE_URL = f"mssql+pyodbc:///?odbc_connect={params}"

engine = create_engine(SQLALCHEMY_DATABASE_URL)
SessionLocal = sessionmaker(autocommit=False, autoflush=False, bind=engine)
Base = declarative_base()

# Dependency to get DB session
def get_db():
    db = SessionLocal()
    try:
        yield db
    finally:
        db.close()