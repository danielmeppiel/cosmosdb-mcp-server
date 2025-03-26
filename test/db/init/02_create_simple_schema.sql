-- Create a new schema
CREATE SCHEMA IF NOT EXISTS simple_schema;

-- Set search path to use the new schema
SET search_path TO simple_schema;

-- Create simple tables
CREATE TABLE IF NOT EXISTS categories (
    category_id BIGINT PRIMARY KEY,
    name VARCHAR(100) NOT NULL,
    description VARCHAR(500)
);

CREATE TABLE IF NOT EXISTS items (
    item_id BIGINT PRIMARY KEY,
    category_id BIGINT,
    name VARCHAR(100) NOT NULL,
    price DECIMAL(10,2) NOT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT fk_category FOREIGN KEY (category_id) REFERENCES categories(category_id)
);

-- Create sequences
CREATE SEQUENCE IF NOT EXISTS seq_category START WITH 1 INCREMENT BY 1;
CREATE SEQUENCE IF NOT EXISTS seq_item START WITH 1 INCREMENT BY 1;

-- Insert sample data into categories
INSERT INTO categories (category_id, name, description)
VALUES 
    (nextval('seq_category'), 'Electronics', 'Electronic devices and gadgets'),
    (nextval('seq_category'), 'Books', 'Books and publications'),
    (nextval('seq_category'), 'Clothing', 'Apparel and accessories');

-- Insert sample data into items
INSERT INTO items (item_id, category_id, name, price)
VALUES 
    (nextval('seq_item'), 1, 'Smartphone', 699.99),
    (nextval('seq_item'), 1, 'Laptop', 1299.99),
    (nextval('seq_item'), 2, 'Python Programming', 49.99),
    (nextval('seq_item'), 2, 'Database Design', 39.99),
    (nextval('seq_item'), 3, 'T-Shirt', 19.99),
    (nextval('seq_item'), 3, 'Jeans', 59.99);

-- Create indexes for better performance
CREATE INDEX IF NOT EXISTS idx_item_category ON items(category_id);

-- Analyze tables for better query performance
ANALYZE categories;
ANALYZE items;