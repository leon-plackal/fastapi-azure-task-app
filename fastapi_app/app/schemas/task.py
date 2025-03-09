from pydantic import BaseModel, Field
from typing import Optional
from datetime import datetime

class TaskBase(BaseModel):
    title: str
    description: Optional[str] = None
    priority: int = Field(1, ge=1, le=3)

class TaskCreate(TaskBase):
    pass

class TaskUpdate(BaseModel):
    title: Optional[str] = None
    description: Optional[str] = None
    is_completed: Optional[bool] = None
    priority: Optional[int] = Field(None, ge=1, le=3)

class TaskResponse(TaskBase):
    id: int
    task_id: str
    is_completed: bool
    created_at: datetime
    updated_at: Optional[datetime] = None
    
    class Config:
        orm_mode = True