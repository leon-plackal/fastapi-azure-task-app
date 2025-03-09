import os
from pydantic_settings import BaseSettings

class Settings(BaseSettings):
    # Azure SQL Database settings
    DB_SERVER: str = os.environ.get("DB_SERVER", "")
    DB_NAME: str = os.environ.get("DB_NAME", "")
    DB_USER: str = os.environ.get("DB_USER", "")
    DB_PASSWORD: str = os.environ.get("DB_PASSWORD", "")
    DB_DRIVER: str = os.environ.get("DB_DRIVER", "ODBC Driver 17 for SQL Server")
    
    # Azure Function settings
    FUNCTION_KEY: str = os.environ.get("FUNCTION_KEY", "")
    FUNCTION_URL: str = os.environ.get("FUNCTION_URL", "")
    
    # Azure AD settings
    AZURE_TENANT_ID: str = os.environ.get("AZURE_TENANT_ID", "")
    AZURE_CLIENT_ID: str = os.environ.get("AZURE_CLIENT_ID", "")
    AZURE_CLIENT_SECRET: str = os.environ.get("AZURE_CLIENT_SECRET", "")
    
    # App settings
    LOG_LEVEL: str = os.environ.get("LOG_LEVEL", "INFO")
    
    class Config:
        env_file = ".env"
        case_sensitive = True

settings = Settings()