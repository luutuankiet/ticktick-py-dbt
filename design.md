# FastAPI Design for TickTick Todo Search

## Project Overview
- **Data Source**: dbt project with TickTick todo data in Postgres
- **Dataset Size**: ~8,000 records, single user
- **Latency Requirement**: 1-2 seconds max
- **Key Feature**: Text search using PostgreSQL's full-text search capabilities

## Database Schema
The main table we're exposing is `fact_todos` which contains:
- Todo metadata (title, content, status)
- Relationship data (list name, folder name)
- Date information (due date, created date, etc.)
- Text search vector column created by the `setup_textsearch` macro

## Architecture

### 1. Database Connection & Dynamic Schema Reflection

```python
from sqlalchemy import create_engine, MetaData
from sqlalchemy.ext.declarative import declarative_base
from sqlalchemy.orm import sessionmaker
from sqlmodel import SQLModel, Field, Session
from typing import Generator

DATABASE_URL = "postgresql://username:password@localhost:5432/ticktick_db"

engine = create_engine(DATABASE_URL)
SessionLocal = sessionmaker(autocommit=False, autoflush=False, bind=engine)
metadata = MetaData()

# Function to get DB session
def get_db() -> Generator[Session, None, None]:
    db = SessionLocal()
    try:
        yield db
    finally:
        db.close()
```

### 2. Dynamic Model Generation

```python
from sqlalchemy import inspect, Column, String, DateTime, Boolean, Integer, Float
from sqlmodel import SQLModel, Field
from typing import Optional, List, Dict, Any
from datetime import datetime
from pydantic import BaseModel

# Dynamic model generation based on database schema
def create_todo_model():
    inspector = inspect(engine)
    columns = inspector.get_columns('fact_todos', schema='marts_core')
    
    attrs = {
        '__tablename__': 'fact_todos',
        '__table_args__': {'schema': 'marts_core'}
    }
    
    # Map SQL types to Python types
    type_map = {
        'character varying': str,
        'text': str,
        'integer': int,
        'boolean': bool,
        'timestamp': datetime,
        'double precision': float,
        # Add more mappings as needed
    }
    
    for column in columns:
        col_name = column['name']
        col_type = type_map.get(str(column['type']), str)
        nullable = column['nullable']
        
        # Create SQLModel Field
        attrs[col_name] = Field(
            default=None if nullable else ...,
            sa_column=Column(col_name, primary_key=(col_name == 'todo_key'))
        )
    
    # Create the model class dynamically
    TodoModel = type('TodoModel', (SQLModel,), attrs)
    return TodoModel

# Create search parameters model
class TodoSearch(BaseModel):
    query: Optional[str] = None
    list_name: Optional[str] = None
    folder_name: Optional[str] = None
    status: Optional[str] = None
    due_date_start: Optional[datetime] = None
    due_date_end: Optional[datetime] = None
    completed: Optional[bool] = None
    page: int = 1
    page_size: int = 20
```

### 3. FastAPI Endpoints

```python
from fastapi import APIRouter, Depends, HTTPException, Query
from sqlalchemy import text
from sqlalchemy.orm import Session
from typing import List, Optional
from datetime import datetime

from app.database import get_db
from app.models import TodoSearch, create_todo_model

router = APIRouter()
TodoModel = create_todo_model()

@router.get("/todos/search", response_model=List[dict])
def search_todos(
    search_params: TodoSearch = Depends(),
    db: Session = Depends(get_db)
):
    # Start with a base query
    query = """
    SELECT * FROM marts_core.fact_todos
    WHERE 1=1
    """
    params = {}
    
    # Add text search if query is provided
    if search_params.query:
        # Using PostgreSQL full-text search with the search column created by setup_textsearch
        query += """
        AND search @@ websearch_to_tsquery('english', :query)
        ORDER BY ts_rank(search, websearch_to_tsquery('english', :query)) DESC
        """
        params["query"] = search_params.query
    
    # Add other filters
    if search_params.list_name:
        query += " AND todo_list_name = :list_name"
        params["list_name"] = search_params.list_name
        
    if search_params.folder_name:
        query += " AND todo_folder_name = :folder_name"
        params["folder_name"] = search_params.folder_name
    
    if search_params.status:
        query += " AND status_id = :status"
        params["status"] = search_params.status
    
    if search_params.due_date_start:
        query += " AND todo_duedate >= :due_date_start"
        params["due_date_start"] = search_params.due_date_start
    
    if search_params.due_date_end:
        query += " AND todo_duedate <= :due_date_end"
        params["due_date_end"] = search_params.due_date_end
    
    if search_params.completed is not None:
        query += " AND todo_status = :completed"
        params["completed"] = "0" if not search_params.completed else "1"
    
    # Add pagination
    query += " LIMIT :limit OFFSET :offset"
    params["limit"] = search_params.page_size
    params["offset"] = (search_params.page - 1) * search_params.page_size
    
    result = db.execute(text(query), params).fetchall()
    
    # Convert to dictionaries
    return [dict(row._mapping) for row in result]

@router.get("/todos/{todo_id}", response_model=dict)
def get_todo(todo_id: str, db: Session = Depends(get_db)):
    result = db.execute(
        text("SELECT * FROM marts_core.fact_todos WHERE todo_id = :todo_id"),
        {"todo_id": todo_id}
    ).first()
    
    if not result:
        raise HTTPException(status_code=404, detail="Todo not found")
    
    return dict(result._mapping)
```

### 4. Main FastAPI App

```python
from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware

from app.api import todos

app = FastAPI(title="TickTick Todo API")

# CORS middleware
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],  # Adjust for production
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# Include routers
app.include_router(todos.router, prefix="/api", tags=["todos"])

@app.get("/")
def read_root():
    return {"message": "Welcome to TickTick Todo API"}

if __name__ == "__main__":
    import uvicorn
    uvicorn.run("app.main:app", host="0.0.0.0", port=8000, reload=True)
```

### 5. Project Structure

```
project/
├── app/
│   ├── __init__.py
│   ├── main.py          # FastAPI app
│   ├── models.py        # SQLModel models
│   ├── database.py      # DB connection
│   └── api/
│       └── todos.py     # Todo endpoints
└── requirements.txt
```

### 6. Requirements

```
fastapi>=0.68.0
uvicorn>=0.15.0
sqlmodel>=0.0.4
psycopg2-binary>=2.9.1
python-dotenv>=0.19.0
```

## Text Search Implementation

The design leverages the PostgreSQL text search capabilities set up by your `setup_textsearch.sql` macro, which:

1. Creates a custom text search configuration
2. Adds a `search` tsvector column to your table
3. Creates a GIN index on this column
4. Sets up a search function

The search endpoint uses this infrastructure by:
- Using `websearch_to_tsquery` for user-friendly search syntax
- Ordering results by rank when search is used
- Combining search with other filters (list, folder, status, dates)

## Next Steps

1. Implement environment configuration for database credentials
2. Add authentication if needed
3. Create a simple frontend for searching todos
4. Consider adding endpoints for other operations (create, update, delete)
5. Add tests for the API endpoints
