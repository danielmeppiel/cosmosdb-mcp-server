import os
from contextlib import asynccontextmanager
from dataclasses import dataclass
from typing import AsyncIterator

import psycopg2
from mcp.server.fastmcp import FastMCP, Context

@dataclass
class DatabaseContext:
    """Context for database connection"""
    conn: psycopg2.extensions.connection

@asynccontextmanager
async def server_lifespan(server: FastMCP) -> AsyncIterator[DatabaseContext]:
    """Manage database connection lifecycle"""
    connection_string = os.getenv("COSMOSDB_CONNECTION_STRING")
    if not connection_string:
        raise ValueError("COSMOSDB_CONNECTION_STRING environment variable is required")
    
    try:
        # Initialize connection on startup
        conn = psycopg2.connect(connection_string)
        yield DatabaseContext(conn=conn)
    finally:
        # Cleanup on shutdown
        if 'conn' in locals():
            conn.close()

# Create MCP server instance
mcp = FastMCP(
    "CosmosDB Schema Explorer",
    lifespan=server_lifespan,
    dependencies=["psycopg2-binary"]
)

@mcp.tool()
def get_table_schema(table_name: str, ctx: Context) -> str:
    """Get the schema definition of a specific table.
    
    Args:
        table_name: The name of the table to get the schema for
        ctx: The MCP context containing the database connection
    
    Returns:
        A string containing the table's schema information including columns, types, and constraints
    """
    db = ctx.request_context.lifespan_context
    cursor = db.conn.cursor()
    
    try:
        # Query to get column information
        cursor.execute("""
            SELECT 
                column_name, 
                data_type,
                character_maximum_length,
                is_nullable,
                column_default
            FROM information_schema.columns 
            WHERE table_name = %s
            ORDER BY ordinal_position
        """, (table_name,))
        
        columns = cursor.fetchall()
        
        if not columns:
            return f"No table found with name '{table_name}'"
        
        # Format the schema information
        schema_info = [f"Table: {table_name}\n"]
        schema_info.append("Columns:")
        for col in columns:
            name, data_type, max_length, nullable, default = col
            type_info = data_type
            if max_length:
                type_info += f"({max_length})"
            nullable_str = "NULL" if nullable == "YES" else "NOT NULL"
            default_str = f" DEFAULT {default}" if default else ""
            
            schema_info.append(f"  - {name}: {type_info} {nullable_str}{default_str}")
        
        return "\n".join(schema_info)
    
    finally:
        cursor.close()

if __name__ == "__main__":
    mcp.run()
