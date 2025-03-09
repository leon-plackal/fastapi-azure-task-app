from fastapi import APIRouter, Depends, HTTPException, BackgroundTasks
from sqlalchemy.orm import Session
import requests
from typing import List
import logging

from app.database import get_db
from app.models.task import Task
from app.schemas.task import TaskCreate, TaskResponse, TaskUpdate
from app.config import settings

router = APIRouter(tags=["tasks"])
logger = logging.getLogger(__name__)

# Function to trigger Azure Function for task processing
def trigger_task_processing(task_id: str):
    try:
        response = requests.post(
            f"{settings.FUNCTION_URL}/api/ProcessTask",
            json={"taskId": task_id},
            headers={"x-functions-key": settings.FUNCTION_KEY}
        )
        response.raise_for_status()
        logger.info(f"Task {task_id} sent for background processing")
    except Exception as e:
        logger.error(f"Failed to trigger task processing: {str(e)}")

@router.post("/tasks/", response_model=TaskResponse)
def create_task(task: TaskCreate, background_tasks: BackgroundTasks, db: Session = Depends(get_db)):
    db_task = Task(**task.dict())
    db.add(db_task)
    db.commit()
    db.refresh(db_task)
    
    # Add background task to trigger Azure Function
    if db_task.priority >= 2:  # Only process medium and high priority tasks asynchronously
        background_tasks.add_task(trigger_task_processing, db_task.task_id)
    
    return db_task

@router.get("/tasks/", response_model=List[TaskResponse])
def read_tasks(skip: int = 0, limit: int = 100, db: Session = Depends(get_db)):
    tasks = db.query(Task).order_by(Task.created_at).offset(skip).limit(limit).all()
    return tasks

@router.get("/tasks/{task_id}", response_model=TaskResponse)
def read_task(task_id: str, db: Session = Depends(get_db)):
    task = db.query(Task).filter(Task.task_id == task_id).first()
    if task is None:
        raise HTTPException(status_code=404, detail="Task not found")
    return task

@router.put("/tasks/{task_id}", response_model=TaskResponse)
def update_task(task_id: str, task_update: TaskUpdate, db: Session = Depends(get_db)):
    db_task = db.query(Task).filter(Task.task_id == task_id).first()
    if db_task is None:
        raise HTTPException(status_code=404, detail="Task not found")
    
    update_data = task_update.dict(exclude_unset=True)
    for key, value in update_data.items():
        setattr(db_task, key, value)
    
    db.commit()
    db.refresh(db_task)
    return db_task

@router.delete("/tasks/{task_id}")
def delete_task(task_id: str, db: Session = Depends(get_db)):
    db_task = db.query(Task).filter(Task.task_id == task_id).first()
    if db_task is None:
        raise HTTPException(status_code=404, detail="Task not found")
    
    db.delete(db_task)
    db.commit()
    return {"message": "Task deleted successfully"}