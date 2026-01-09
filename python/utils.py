"""
Utility functions for Funnel Optimization Project
Handles database connections, logging, and shared data operations
"""

import os
from typing import Optional, Dict, Any
import pandas as pd
from sqlalchemy import create_engine, text
from sqlalchemy.engine import Engine
from dotenv import load_dotenv
import logging

# Configure logging
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(name)s - %(levelname)s - %(message)s'
)
logger = logging.getLogger(__name__)


class DatabaseConnection:
    """
    Manages MySQL database connections using SQLAlchemy
    Loads credentials securely from .env file
    """
    
    def __init__(self, env_path: Optional[str] = None):
        """
        Initialize database connection
        
        Args:
            env_path: Path to .env file (defaults to project root)
        """
        if env_path:
            load_dotenv(env_path)
        else:
            # Look for .env in parent directory (project root)
            current_dir = os.path.dirname(os.path.abspath(__file__))
            project_root = os.path.dirname(current_dir)
            env_file = os.path.join(project_root, '.env')
            load_dotenv(env_file)
        
        self.host = os.getenv('DB_HOST', 'localhost')
        self.port = os.getenv('DB_PORT', '3306')
        self.user = os.getenv('DB_USER', 'root')
        self.password = os.getenv('DB_PASSWORD')
        self.database = os.getenv('DB_NAME', 'funnel_project')
        
        if not self.password:
            raise ValueError("DB_PASSWORD not found in environment variables")
        
        self.engine: Optional[Engine] = None
        self._connect()
    
    def _connect(self):
        """Create SQLAlchemy engine"""
        from urllib.parse import quote_plus
        
        # URL-encode password to handle special characters like @ # $ etc.
        encoded_password = quote_plus(self.password)
        
        connection_string = (
            f"mysql+pymysql://{self.user}:{encoded_password}"
            f"@{self.host}:{self.port}/{self.database}"
        )
        self.engine = create_engine(connection_string, echo=False)
        logger.info(f"Connected to database: {self.database}")
    
    def execute_query(self, query: str, params: Optional[Dict[str, Any]] = None) -> pd.DataFrame:
        """
        Execute a SELECT query and return results as DataFrame
        
        Args:
            query: SQL query string
            params: Optional query parameters
            
        Returns:
            DataFrame with query results
        """
        try:
            with self.engine.connect() as conn:
                df = pd.read_sql(text(query), conn, params=params)
            logger.info(f"Query executed successfully. Rows returned: {len(df)}")
            return df
        except Exception as e:
            logger.error(f"Query execution failed: {str(e)}")
            raise
    
    def execute_nonquery(self, query: str, params: Optional[Dict[str, Any]] = None) -> int:
        """
        Execute a non-SELECT query (INSERT, UPDATE, DELETE, TRUNCATE)
        
        Args:
            query: SQL query string
            params: Optional query parameters
            
        Returns:
            Number of rows affected
        """
        try:
            with self.engine.connect() as conn:
                result = conn.execute(text(query), params or {})
                conn.commit()
                rows_affected = result.rowcount
            logger.info(f"Non-query executed successfully. Rows affected: {rows_affected}")
            return rows_affected
        except Exception as e:
            logger.error(f"Non-query execution failed: {str(e)}")
            raise
    
    def execute_script(self, script_path: str):
        """
        Execute a SQL script file containing multiple statements
        
        Args:
            script_path: Path to .sql file
        """
        try:
            with open(script_path, 'r') as f:
                sql_script = f.read()
            
            # Split by semicolons, but keep them
            # Remove comments and empty lines
            statements = []
            current_statement = []
            
            for line in sql_script.split('\n'):
                # Skip comment-only lines
                if line.strip().startswith('--'):
                    continue
                
                # Remove inline comments
                line_without_comment = line.split('--')[0].strip()
                
                if line_without_comment:
                    current_statement.append(line)
                    
                    # Check if line ends with semicolon
                    if line_without_comment.endswith(';'):
                        stmt = '\n'.join(current_statement)
                        if stmt.strip():
                            statements.append(stmt)
                        current_statement = []
            
            # Execute each statement
            with self.engine.connect() as conn:
                for i, statement in enumerate(statements, 1):
                    try:
                        conn.execute(text(statement))
                        conn.commit()
                    except Exception as e:
                        logger.warning(f"Statement {i} failed (may be expected): {str(e)[:100]}")
            
            logger.info(f"Script executed: {script_path} ({len(statements)} statements)")
        except Exception as e:
            logger.error(f"Script execution failed: {str(e)}")
            raise
    
    def get_table(self, table_name: str, limit: Optional[int] = None) -> pd.DataFrame:
        """
        Load entire table into DataFrame
        
        Args:
            table_name: Name of table to load
            limit: Optional row limit for testing
            
        Returns:
            DataFrame with table contents
        """
        query = f"SELECT * FROM {table_name}"
        if limit:
            query += f" LIMIT {limit}"
        
        return self.execute_query(query)
    
    def close(self):
        """Close database connection"""
        if self.engine:
            self.engine.dispose()
            logger.info("Database connection closed")


def validate_dataframe(df: pd.DataFrame, name: str, expected_cols: Optional[list] = None):
    """
    Validate DataFrame structure and log summary
    
    Args:
        df: DataFrame to validate
        name: Name for logging
        expected_cols: Optional list of required columns
    """
    logger.info(f"\n{'='*60}")
    logger.info(f"Validating DataFrame: {name}")
    logger.info(f"{'='*60}")
    logger.info(f"Shape: {df.shape}")
    logger.info(f"Columns: {list(df.columns)}")
    logger.info(f"Memory usage: {df.memory_usage(deep=True).sum() / 1024**2:.2f} MB")
    
    if expected_cols:
        missing_cols = set(expected_cols) - set(df.columns)
        if missing_cols:
            raise ValueError(f"Missing required columns: {missing_cols}")
        logger.info(f"✅ All expected columns present")
    
    # Check for missing values
    null_counts = df.isnull().sum()
    if null_counts.sum() > 0:
        logger.warning(f"Null values found:\n{null_counts[null_counts > 0]}")
    else:
        logger.info("✅ No null values")
    
    logger.info(f"{'='*60}\n")


def save_results(data: Any, path: str, file_format: str = 'csv'):
    """
    Save results to file with proper formatting
    
    Args:
        data: Data to save (DataFrame, dict, etc.)
        path: Output file path
        file_format: Format ('csv', 'parquet', 'json')
    """
    os.makedirs(os.path.dirname(path), exist_ok=True)
    
    if isinstance(data, pd.DataFrame):
        if file_format == 'csv':
            data.to_csv(path, index=False)
        elif file_format == 'parquet':
            data.to_parquet(path, index=False)
        else:
            raise ValueError(f"Unsupported format for DataFrame: {file_format}")
    elif isinstance(data, dict):
        import json
        with open(path, 'w') as f:
            json.dump(data, f, indent=2)
    else:
        raise ValueError(f"Unsupported data type: {type(data)}")
    
    logger.info(f"Results saved to: {path}")
