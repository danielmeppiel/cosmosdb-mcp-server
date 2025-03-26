-- PostgreSQL initialization script for Azure CosmosDB

-- Create sequences for all primary keys
DO $$
BEGIN
    FOR i IN 1..1200 LOOP
        EXECUTE format('CREATE SEQUENCE IF NOT EXISTS seq_%s INCREMENT BY 1 START WITH 1 NO CYCLE', i);
    END LOOP;
END $$;

CREATE TABLE IF NOT EXISTS departments (
    dept_id BIGINT PRIMARY KEY,
    name VARCHAR(100) NOT NULL,
    location VARCHAR(100),
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE IF NOT EXISTS job_titles (
    title_id BIGINT PRIMARY KEY,
    title_name VARCHAR(100) NOT NULL,
    min_salary DECIMAL(10,2),
    max_salary DECIMAL(10,2),
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE IF NOT EXISTS employee_grades (
    grade_id BIGINT PRIMARY KEY,
    grade_name VARCHAR(50) NOT NULL,
    grade_level INTEGER NOT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE IF NOT EXISTS employees (
    employee_id BIGINT PRIMARY KEY,
    dept_id BIGINT,
    title_id BIGINT,
    grade_id BIGINT,
    first_name VARCHAR(50) NOT NULL,
    last_name VARCHAR(50) NOT NULL,
    email VARCHAR(100) UNIQUE NOT NULL,
    hire_date DATE,
    salary DECIMAL(10,2),
    status VARCHAR(20) DEFAULT 'ACTIVE' CHECK (status IN ('ACTIVE', 'TERMINATED', 'ON_LEAVE', 'SUSPENDED')),
    manager_id BIGINT,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT fk_dept FOREIGN KEY (dept_id) REFERENCES departments(dept_id),
    CONSTRAINT fk_title FOREIGN KEY (title_id) REFERENCES job_titles(title_id),
    CONSTRAINT fk_grade FOREIGN KEY (grade_id) REFERENCES employee_grades(grade_id),
    CONSTRAINT fk_manager FOREIGN KEY (manager_id) REFERENCES employees(employee_id)
);

CREATE TABLE IF NOT EXISTS employee_history (
    history_id BIGINT PRIMARY KEY,
    employee_id BIGINT,
    dept_id BIGINT,
    title_id BIGINT,
    grade_id BIGINT,
    salary DECIMAL(10,2),
    status VARCHAR(20),
    effective_from DATE,
    effective_to DATE,
    change_reason VARCHAR(200),
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT fk_emp_hist FOREIGN KEY (employee_id) REFERENCES employees(employee_id)
);

-- Generate 48 HR attribute tables
DO $$ 
BEGIN
    FOR i IN 1..48 LOOP
        EXECUTE format('
            CREATE TABLE IF NOT EXISTS hr_attribute_%s (
                id BIGINT PRIMARY KEY,
                employee_id BIGINT,
                attribute_value VARCHAR(100),
                created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
                CONSTRAINT fk_emp_%s FOREIGN KEY (employee_id) REFERENCES employees(employee_id)
            )', i, i);
    END LOOP;
END $$;

-- Sales and Order Management Domain
CREATE TABLE IF NOT EXISTS customers (
    customer_id BIGINT PRIMARY KEY,
    name VARCHAR(100) NOT NULL,
    email VARCHAR(100) UNIQUE NOT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Generate 199 sales-related tables
DO $$ 
BEGIN
    FOR i IN 1..199 LOOP
        EXECUTE format('
            CREATE TABLE IF NOT EXISTS sales_data_%s (
                id BIGINT PRIMARY KEY,
                customer_id BIGINT,
                transaction_date TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
                amount DECIMAL(10,2),
                CONSTRAINT fk_cust_%s FOREIGN KEY (customer_id) REFERENCES customers(customer_id)
            )', i, i);
    END LOOP;
END $$;

-- Product and Inventory Domain
CREATE TABLE IF NOT EXISTS product_categories (
    category_id BIGINT PRIMARY KEY,
    name VARCHAR(100) NOT NULL,
    description VARCHAR(500),
    parent_category_id BIGINT,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT fk_parent_category FOREIGN KEY (parent_category_id) REFERENCES product_categories(category_id)
);

CREATE TABLE IF NOT EXISTS products (
    product_id BIGINT PRIMARY KEY,
    category_id BIGINT,
    sku VARCHAR(50) UNIQUE NOT NULL,
    name VARCHAR(100) NOT NULL,
    description VARCHAR(500),
    weight DECIMAL(10,2),
    dimensions VARCHAR(50),
    is_active CHAR(1) DEFAULT '1' CHECK (is_active IN ('0','1')),
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT fk_category FOREIGN KEY (category_id) REFERENCES product_categories(category_id)
);

CREATE TABLE IF NOT EXISTS product_prices (
    price_id BIGINT PRIMARY KEY,
    product_id BIGINT,
    base_price DECIMAL(10,2) NOT NULL,
    discount_price DECIMAL(10,2),
    effective_from TIMESTAMP NOT NULL,
    effective_to TIMESTAMP,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT fk_product_price FOREIGN KEY (product_id) REFERENCES products(product_id)
);

-- Order Management tables
CREATE TABLE IF NOT EXISTS order_status (
    status_id BIGINT PRIMARY KEY,
    status_name VARCHAR(50) NOT NULL,
    description VARCHAR(200)
);

CREATE TABLE IF NOT EXISTS orders (
    order_id BIGINT PRIMARY KEY,
    customer_id BIGINT,
    employee_id BIGINT,
    order_date TIMESTAMP,
    status_id BIGINT,
    total_amount DECIMAL(10,2),
    shipping_address VARCHAR(500),
    billing_address VARCHAR(500),
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT fk_order_customer FOREIGN KEY (customer_id) REFERENCES customers(customer_id),
    CONSTRAINT fk_order_employee FOREIGN KEY (employee_id) REFERENCES employees(employee_id),
    CONSTRAINT fk_order_status FOREIGN KEY (status_id) REFERENCES order_status(status_id)
);

CREATE TABLE IF NOT EXISTS order_items (
    item_id BIGINT PRIMARY KEY,
    order_id BIGINT,
    product_id BIGINT,
    quantity INTEGER NOT NULL,
    unit_price DECIMAL(10,2) NOT NULL,
    discount_amount DECIMAL(10,2) DEFAULT 0,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT fk_order_item_order FOREIGN KEY (order_id) REFERENCES orders(order_id),
    CONSTRAINT fk_order_item_product FOREIGN KEY (product_id) REFERENCES products(product_id)
);

-- Generate 199 inventory-related tables
DO $$ 
BEGIN
    FOR i IN 1..199 LOOP
        EXECUTE format('
            CREATE TABLE IF NOT EXISTS inventory_data_%s (
                id BIGINT PRIMARY KEY,
                product_id BIGINT,
                quantity INTEGER,
                last_updated TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
                CONSTRAINT fk_prod_%s FOREIGN KEY (product_id) REFERENCES products(product_id)
            )', i, i);
    END LOOP;
END $$;

-- Finance Domain
CREATE TABLE IF NOT EXISTS accounts (
    account_id BIGINT PRIMARY KEY,
    customer_id BIGINT,
    account_number VARCHAR(20) UNIQUE NOT NULL,
    account_type VARCHAR(50) NOT NULL,
    balance DECIMAL(15,2),
    status VARCHAR(20) DEFAULT 'ACTIVE' CHECK (status IN ('ACTIVE', 'FROZEN', 'CLOSED')),
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT fk_account_customer FOREIGN KEY (customer_id) REFERENCES customers(customer_id)
);

CREATE TABLE IF NOT EXISTS transactions (
    transaction_id BIGINT PRIMARY KEY,
    account_id BIGINT NOT NULL,
    order_id BIGINT,
    transaction_type VARCHAR(20) NOT NULL CHECK (transaction_type IN ('PURCHASE', 'REFUND', 'DEPOSIT', 'WITHDRAWAL')),
    amount DECIMAL(15,2) NOT NULL CHECK (amount != 0),
    status VARCHAR(20) NOT NULL DEFAULT 'PENDING' CHECK (status IN ('PENDING', 'COMPLETED', 'FAILED', 'REVERSED')),
    transaction_date TIMESTAMP NOT NULL,
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT fk_trans_account FOREIGN KEY (account_id) REFERENCES accounts(account_id),
    CONSTRAINT fk_trans_order FOREIGN KEY (order_id) REFERENCES orders(order_id)
);

-- Generate 199 finance-related tables
DO $$ 
BEGIN
    FOR i IN 1..199 LOOP
        EXECUTE format('
            CREATE TABLE IF NOT EXISTS finance_data_%s (
                id BIGINT PRIMARY KEY,
                account_id BIGINT NOT NULL,
                transaction_amount DECIMAL(15,2) NOT NULL CHECK (transaction_amount != 0),
                transaction_date TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
                CONSTRAINT fk_acc_%s FOREIGN KEY (account_id) REFERENCES accounts(account_id)
            )', i, i);
    END LOOP;
END $$;

-- Operations Domain
CREATE TABLE IF NOT EXISTS facilities (
    facility_id BIGINT PRIMARY KEY,
    name VARCHAR(100) NOT NULL,
    location VARCHAR(100),
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Generate 199 operations-related tables
DO $$ 
BEGIN
    FOR i IN 1..199 LOOP
        EXECUTE format('
            CREATE TABLE IF NOT EXISTS operations_data_%s (
                id BIGINT PRIMARY KEY,
                facility_id BIGINT,
                operation_date TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
                status VARCHAR(20),
                CONSTRAINT fk_fac_%s FOREIGN KEY (facility_id) REFERENCES facilities(facility_id)
            )', i, i);
    END LOOP;
END $$;

-- Customer Service Domain
CREATE TABLE IF NOT EXISTS tickets (
    ticket_id BIGINT PRIMARY KEY,
    customer_id BIGINT,
    status VARCHAR(20),
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT fk_ticket_cust FOREIGN KEY (customer_id) REFERENCES customers(customer_id)
);

-- Generate 149 customer service related tables
DO $$ 
BEGIN
    FOR i IN 1..149 LOOP
        EXECUTE format('
            CREATE TABLE IF NOT EXISTS service_data_%s (
                id BIGINT PRIMARY KEY,
                ticket_id BIGINT,
                resolution_time TIMESTAMP,
                satisfaction_score INTEGER,
                CONSTRAINT fk_tick_%s FOREIGN KEY (ticket_id) REFERENCES tickets(ticket_id)
            )', i, i);
    END LOOP;
END $$;

-- Create indexes for better performance
DO $$ 
BEGIN
    -- Create indexes for HR tables with CONCURRENTLY
    FOR i IN 1..48 LOOP
        EXECUTE format('CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_hr_%s_emp ON hr_attribute_%s(employee_id)', i, i);
    END LOOP;

    -- Create indexes for Sales tables
    FOR i IN 1..199 LOOP
        EXECUTE format('CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_sales_%s_cust ON sales_data_%s(customer_id)', i, i);
    END LOOP;

    -- Create indexes for Inventory tables
    FOR i IN 1..199 LOOP
        EXECUTE format('CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_inv_%s_prod ON inventory_data_%s(product_id)', i, i);
    END LOOP;

    -- Create indexes for Finance tables
    FOR i IN 1..199 LOOP
        EXECUTE format('CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_fin_%s_acc ON finance_data_%s(account_id)', i, i);
        EXECUTE format('CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_fin_%s_date ON finance_data_%s(transaction_date)', i, i);
    END LOOP;

    -- Create indexes for Operations tables
    FOR i IN 1..199 LOOP
        EXECUTE format('CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_ops_%s_fac ON operations_data_%s(facility_id)', i, i);
        EXECUTE format('CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_ops_%s_date ON operations_data_%s(operation_date)', i, i);
    END LOOP;

    -- Create indexes for Customer Service tables
    FOR i IN 1..149 LOOP
        EXECUTE format('CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_serv_%s_tick ON service_data_%s(ticket_id)', i, i);
    END LOOP;

    -- Create additional indexes for performance
    CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_emp_manager ON employees(manager_id);
    CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_emp_title ON employees(title_id);
    CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_emp_grade ON employees(grade_id);
    CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_emp_status ON employees(status);
    CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_emp_email ON employees(email);
    CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_prod_category ON products(category_id);
    CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_prod_sku ON products(sku);
    CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_price_product ON product_prices(product_id);
    CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_price_effective ON product_prices(effective_from, effective_to);
    CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_order_customer ON orders(customer_id);
    CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_order_employee ON orders(employee_id);
    CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_order_status ON orders(status_id);
    CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_order_date ON orders(order_date);
    CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_trans_order ON transactions(order_id);
    CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_trans_account ON transactions(account_id);
    CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_trans_date ON transactions(transaction_date);
END $$;