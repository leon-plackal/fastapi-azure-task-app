# ProcessTask/__init__.py
import logging
import azure.functions as func
import pyodbc
import os
import json
import time
from datetime import datetime

def main(req: func.HttpRequest) -> func.HttpResponse:
    logging.info('Python HTTP trigger function processed a request.')

    try:
        req_body = req.get_json()
        task_id = req_body.get('taskId')
        
        if not task_id:
            return func.HttpResponse(
                "Please pass a taskId in the request body",
                status_code=400
            )
        
        # Connect to Azure SQL Database
        conn_str = (
            f"Driver={{{os.environ['DB_DRIVER']}}};Server=tcp:{os.environ['DB_SERVER']},1433;"
            f"Database={os.environ['DB_NAME']};Uid={os.environ['DB_USER']};"
            f"Pwd={os.environ['DB_PASSWORD']};Encrypt=yes;TrustServerCertificate=no;"
            f"Connection Timeout=30;"
        )
        
        # Simulate task processing with delay
        logging.info(f"Processing task {task_id}...")
        time.sleep(5)  # Simulate processing time
        
        # Update task in database to indicate processing is complete
        conn = pyodbc.connect(conn_str)
        cursor = conn.cursor()
        
        # Get task details
        cursor.execute("SELECT title, priority FROM tasks WHERE task_id = ?", task_id)
        row = cursor.fetchone()
        
        if not row:
            return func.HttpResponse(f"Task {task_id} not found", status_code=404)
        
        task_title = row[0]
        priority = row[1]
        
        # Log processing details
        processing_details = {
            "task_id": task_id,
            "title": task_title,
            "priority": priority,
            "processed_at": datetime.now().isoformat(),
            "status": "completed"
        }
        
        logging.info(f"Task processing completed: {json.dumps(processing_details)}")
        
        # Update the task in the database (you could mark it as processed or add processing details)
        cursor.execute(
            "UPDATE tasks SET description = CONCAT(description, ' [Processed at ' + ? + ']') WHERE task_id = ?",
            datetime.now().isoformat(), task_id
        )
        conn.commit()
        conn.close()
        
        return func.HttpResponse(
            json.dumps(processing_details),
            mimetype="application/json",
            status_code=200
        )
            
    except Exception as e:
        logging.error(f"Error processing task: {str(e)}")
        return func.HttpResponse(
            f"Error processing task: {str(e)}",
            status_code=500
        )