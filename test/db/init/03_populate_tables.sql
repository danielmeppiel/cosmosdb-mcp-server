-- Note: Connection settings should be handled by environment variables or connection string
-- in Azure Cosmos DB for PostgreSQL

DO $$
DECLARE
    v_sql text;
BEGIN
    -- First, truncate all child tables that don't have dependencies
    -- Customer Service tables
    FOR i IN 1..149 LOOP
        EXECUTE format('TRUNCATE TABLE service_data_%s CASCADE', i);
    END LOOP;

    -- Operations tables
    FOR i IN 1..199 LOOP
        EXECUTE format('TRUNCATE TABLE operations_data_%s CASCADE', i);
    END LOOP;

    -- Finance data tables
    FOR i IN 1..199 LOOP
        EXECUTE format('TRUNCATE TABLE finance_data_%s CASCADE', i);
    END LOOP;

    -- Sales data tables
    FOR i IN 1..199 LOOP
        EXECUTE format('TRUNCATE TABLE sales_data_%s CASCADE', i);
    END LOOP;

    -- Inventory data tables
    FOR i IN 1..199 LOOP
        EXECUTE format('TRUNCATE TABLE inventory_data_%s CASCADE', i);
    END LOOP;

    -- HR attribute tables
    FOR i IN 1..48 LOOP
        EXECUTE format('TRUNCATE TABLE hr_attribute_%s CASCADE', i);
    END LOOP;

    -- Now truncate main tables in reverse dependency order
    TRUNCATE TABLE transactions CASCADE;
    TRUNCATE TABLE order_items CASCADE;
    TRUNCATE TABLE orders CASCADE;
    TRUNCATE TABLE tickets CASCADE;
    TRUNCATE TABLE product_prices CASCADE;
    TRUNCATE TABLE products CASCADE;
    TRUNCATE TABLE product_categories CASCADE;
    TRUNCATE TABLE accounts CASCADE;
    TRUNCATE TABLE employee_history CASCADE;
    TRUNCATE TABLE employees CASCADE;
    TRUNCATE TABLE employee_grades CASCADE;
    TRUNCATE TABLE job_titles CASCADE;
    TRUNCATE TABLE departments CASCADE;
    TRUNCATE TABLE customers CASCADE;
    TRUNCATE TABLE facilities CASCADE;
    TRUNCATE TABLE order_status CASCADE;

    -- Insert departments
    INSERT INTO departments 
    SELECT generate_series(1, 10) as id, 
           'Department ' || generate_series(1, 10), 
           'Location ' || generate_series(1, 10), 
           CURRENT_TIMESTAMP;

    -- Insert job titles with realistic salary ranges
    INSERT INTO job_titles (title_id, title_name, min_salary, max_salary)
    VALUES 
    (1, 'Junior Associate', 35000, 55000),
    (2, 'Associate', 45000, 75000),
    (3, 'Senior Associate', 65000, 95000),
    (4, 'Manager', 85000, 120000),
    (5, 'Senior Manager', 100000, 150000),
    (6, 'Director', 130000, 200000),
    (7, 'VP', 180000, 300000),
    (8, 'SVP', 250000, 400000),
    (9, 'EVP', 300000, 500000),
    (10, 'C-Level', 400000, 1000000);

    -- Insert employee grades
    INSERT INTO employee_grades (grade_id, grade_name, grade_level)
    VALUES 
    (1, 'Entry Level', 1),
    (2, 'Junior', 2),
    (3, 'Intermediate', 3),
    (4, 'Senior', 4),
    (5, 'Expert', 5),
    (6, 'Master', 6);

    -- Insert employees with realistic data distribution - managers first
    -- First pass: Insert managers (no manager references)
    INSERT INTO employees (
        employee_id, dept_id, title_id, grade_id, first_name, last_name, 
        email, hire_date, salary, status, manager_id
    )
    SELECT 
        id,
        (id % 10) + 1,
        CASE 
            WHEN id <= 5 THEN floor(random() * 3 + 8)  -- Top management
            ELSE floor(random() * 2 + 6)               -- Mid management
        END,
        CASE 
            WHEN id <= 5 THEN 6  -- Top management grade
            ELSE 5              -- Mid management grade
        END,
        'FirstName' || id,
        'LastName' || id,
        'email' || id || '@example.com',
        CURRENT_DATE - (random() * 3650)::integer,  -- Longer tenure for managers
        CASE 
            WHEN id <= 5 THEN floor(random() * (1000000 - 400000) + 400000)
            ELSE floor(random() * (400000 - 200000) + 200000)
        END,
        'ACTIVE',  -- Managers are always active
        NULL       -- Top level has no managers
    FROM generate_series(1, 20) as id;  -- Create 20 managers first

    -- Second pass: Insert regular employees with manager references
    INSERT INTO employees (
        employee_id, dept_id, title_id, grade_id, first_name, last_name, 
        email, hire_date, salary, status, manager_id
    )
    SELECT 
        id + 20,  -- Start IDs after managers
        (id % 10) + 1,
        floor(random() * 3 + 1),  -- Regular employee titles
        floor(random() * 3 + 1),  -- Regular employee grades
        'FirstName' || (id + 20),
        'LastName' || (id + 20),
        'email' || (id + 20) || '@example.com',
        CURRENT_DATE - (random() * 1500)::integer,
        floor(random() * (100000 - 35000) + 35000),
        CASE 
            WHEN random() > 0.95 THEN 'TERMINATED'
            WHEN random() > 0.90 THEN 'ON_LEAVE'
            ELSE 'ACTIVE'
        END,
        floor(random() * 19 + 1)  -- Randomly assign to one of the 20 managers
    FROM generate_series(1, 80) as id;  -- Create 80 regular employees

    -- Insert customers
    INSERT INTO customers 
    SELECT generate_series(1, 1000) as id,
           'Customer ' || generate_series(1, 1000),
           'customer' || generate_series(1, 1000) || '@example.com',
           CURRENT_TIMESTAMP;

    -- Insert product categories
    INSERT INTO product_categories (category_id, name, description, parent_category_id)
    VALUES
    (1, 'Electronics', 'Electronic devices and accessories', NULL),
    (2, 'Computers', 'Computer systems and parts', 1),
    (3, 'Smartphones', 'Mobile phones and accessories', 1),
    (4, 'Clothing', 'Apparel and accessories', NULL),
    (5, 'Men''s Wear', 'Men''s clothing', 4),
    (6, 'Women''s Wear', 'Women''s clothing', 4);

    -- Insert products with more realistic data
    INSERT INTO products (
        product_id, category_id, sku, name, description, 
        weight, dimensions, is_active
    )
    SELECT 
        id,
        (id % 6) + 1,
        'SKU-' || LPAD(id::text, 6, '0'),
        'Product ' || id,
        'Description for product ' || id,
        round((random() * (50 - 0.1) + 0.1)::numeric, 2),
        round((random() * 100)::numeric)::text || 'x' || 
        round((random() * 100)::numeric)::text || 'x' || 
        round((random() * 100)::numeric)::text,
        CASE WHEN random() > 0.1 THEN '1' ELSE '0' END
    FROM generate_series(1, 1000) as id;

    -- Insert product prices with history
    INSERT INTO product_prices (
        price_id, product_id, base_price, discount_price,
        effective_from, effective_to
    )
    SELECT 
        id,
        (id - 1) % 1000 + 1,
        round((random() * (5000 - 10) + 10)::numeric, 2),
        CASE WHEN random() > 0.7 
             THEN round((random() * (4000 - 5) + 5)::numeric, 2)
             ELSE NULL
        END,
        CURRENT_DATE - interval '1 year' + ((id - 1) % 4) * interval '3 month',
        CASE WHEN (id - 1) % 4 < 3 
             THEN CURRENT_DATE - interval '1 year' + (((id - 1) % 4) + 1) * interval '3 month'
             ELSE NULL
        END
    FROM generate_series(1, 4000) as id;

    -- Insert order statuses
    INSERT INTO order_status (status_id, status_name, description)
    VALUES
    (1, 'PENDING', 'Order created but not confirmed'),
    (2, 'CONFIRMED', 'Order confirmed, awaiting processing'),
    (3, 'PROCESSING', 'Order is being processed'),
    (4, 'SHIPPED', 'Order has been shipped'),
    (5, 'DELIVERED', 'Order has been delivered'),
    (6, 'CANCELLED', 'Order was cancelled'),
    (7, 'RETURNED', 'Order was returned');

    -- Insert accounts with varying types and balances
    INSERT INTO accounts 
    SELECT id,
           id, -- Direct mapping to customer_id (since we have 1000 customers)
           'ACC' || LPAD(id::text, 10, '0'),
           CASE 
               WHEN id <= 200 THEN 'SAVINGS'
               WHEN id <= 400 THEN 'CHECKING'
               WHEN id <= 600 THEN 'CREDIT'
               ELSE 'LOAN'
           END,
           10000 + (id % 90000),
           CASE 
               WHEN random() > 0.95 THEN 'CLOSED'
               WHEN random() > 0.90 THEN 'FROZEN'
               ELSE 'ACTIVE'
           END,
           CURRENT_TIMESTAMP
    FROM generate_series(1, 1000) as id;

    -- Insert facilities
    INSERT INTO facilities 
    SELECT generate_series(1, 100) as id,
           'Facility ' || generate_series(1, 100),
           'Location ' || generate_series(1, 100),
           CURRENT_TIMESTAMP;

    -- Insert tickets
    INSERT INTO tickets 
    SELECT g.id,
           (g.id % 1000) + 1 as customer_id,
           CASE (g.id % 3) 
               WHEN 0 THEN 'OPEN'
               WHEN 1 THEN 'IN_PROGRESS'
               ELSE 'CLOSED'
           END as status,
           CURRENT_TIMESTAMP
    FROM generate_series(1, 1000) as g(id);

    -- Insert orders with realistic patterns
    INSERT INTO orders (
        order_id,
        customer_id,
        employee_id,
        order_date,
        status_id,
        shipping_address,
        billing_address,
        created_at
    )
    SELECT 
        id as order_id,
        floor(random() * 1000 + 1) as customer_id,
        floor(random() * 100 + 1) as employee_id,
        CURRENT_TIMESTAMP - (random() * 365)::integer * interval '1 day' as order_date,
        CASE 
            WHEN random() > 0.95 THEN 6  -- CANCELLED
            WHEN random() > 0.90 THEN 7  -- RETURNED
            ELSE floor(random() * 5 + 1) -- Other statuses
        END as status_id,
        'Shipping Address ' || id,
        'Billing Address ' || id,
        CURRENT_TIMESTAMP - (random() * 365)::integer * interval '1 day'
    FROM generate_series(1, 5000) as id;

    -- Insert order items with varying quantities and prices
    INSERT INTO order_items (
        item_id,
        order_id,
        product_id,
        quantity,
        unit_price,
        discount_amount
    )
    WITH random_items AS (
        SELECT 
            id as item_id,
            floor(random() * 5000 + 1) as order_id,
            floor(random() * 1000 + 1) as product_id,
            floor(random() * 10 + 1) as quantity
        FROM generate_series(1, 15000) as id
    ),
    latest_prices AS (
        SELECT 
            product_id,
            base_price,
            discount_price,
            row_number() OVER (PARTITION BY product_id ORDER BY effective_from DESC) as rn
        FROM product_prices
        WHERE effective_from <= CURRENT_DATE
        AND (effective_to IS NULL OR effective_to > CURRENT_DATE)
    )
    SELECT 
        ri.item_id,
        ri.order_id,
        ri.product_id,
        ri.quantity,
        COALESCE(lp.discount_price, lp.base_price)::numeric as unit_price,
        CASE 
            WHEN lp.discount_price IS NOT NULL 
            THEN ROUND(((lp.base_price - lp.discount_price) * ri.quantity)::numeric, 2)
            ELSE 0::numeric
        END as discount_amount
    FROM random_items ri
    JOIN latest_prices lp ON ri.product_id = lp.product_id AND lp.rn = 1;

    -- Update order totals based on items
    UPDATE orders o
    SET total_amount = (
        SELECT SUM((quantity * unit_price) - discount_amount)
        FROM order_items oi
        WHERE oi.order_id = o.order_id
    );

    -- Create transactions for orders
    INSERT INTO transactions (
        transaction_id,
        account_id,
        order_id,
        transaction_type,
        amount,
        status,
        transaction_date,
        created_at
    )
    SELECT 
        nextval('seq_1000'),
        a.account_id,
        o.order_id,
        CASE 
            WHEN o.status_id = 7 THEN 'REFUND'     -- RETURNED orders
            ELSE 'PURCHASE'                         -- All other orders
        END,
        CASE 
            WHEN o.status_id = 7 THEN -o.total_amount  -- Negative amount for refunds
            ELSE o.total_amount                        -- Positive amount for purchases
        END,
        CASE 
            WHEN o.status_id IN (1, 2) THEN 'PENDING'  -- PENDING or CONFIRMED orders
            WHEN o.status_id = 6 THEN 'FAILED'         -- CANCELLED orders
            ELSE 'COMPLETED'                           -- All other orders
        END,
        o.order_date,
        o.created_at
    FROM orders o
    JOIN customers c ON o.customer_id = c.customer_id
    JOIN accounts a ON c.customer_id = a.customer_id
    WHERE o.order_id <= 5000;  -- More explicit limit

    -- Populate HR attribute tables with realistic employee attributes
    FOR i IN 1..48 LOOP
        v_sql := format('
            INSERT INTO hr_attribute_%s 
            SELECT 
                nextval(''seq_%s''), 
                e.employee_id,
                CASE (lvl.value %% 5)
                    WHEN 0 THEN ''Experience Level '' || (random() * 10 + 1)::integer
                    WHEN 1 THEN ''Certification '' || (random() * 5 + 1)::integer
                    WHEN 2 THEN ''Skill Rating '' || (random() * 100 + 1)::integer
                    WHEN 3 THEN ''Training Score '' || (random() * 40 + 60)::integer
                    ELSE ''Performance Index '' || (random() * 5 + 1)::integer
                END,
                CURRENT_TIMESTAMP - (random() * 365 * interval ''1 day'')
            FROM employees e
            CROSS JOIN generate_series(1, 10) AS lvl(value)', 
            i, i);
        EXECUTE v_sql;
    END LOOP;

    -- Populate Sales tables with transaction data
    FOR i IN 1..199 LOOP
        v_sql := format('
            INSERT INTO sales_data_%s
            SELECT 
                nextval(''seq_%s''), 
                c.customer_id,
                CURRENT_TIMESTAMP - (random() * 730 * interval ''1 day''),
                round((random() * 4990 + 10)::numeric, 2)
            FROM customers c
            CROSS JOIN generate_series(1, 50) AS s
            WHERE c.customer_id <= 1000', 
            i, i + 100);
        EXECUTE v_sql;
    END LOOP;

    -- Populate Inventory tables with stock data
    FOR i IN 1..199 LOOP
        v_sql := 'INSERT INTO inventory_data_' || i || '
            SELECT 
                nextval(''seq_' || (i+300) || '''), 
                p.product_id,
                floor(random() * 1000),
                CURRENT_TIMESTAMP - (random() * 90)::integer * interval ''1 day''
            FROM products p,
                 generate_series(1, 20) as l(col)';
        EXECUTE v_sql;
    END LOOP;

    -- Populate Finance tables with transaction data
    FOR i IN 1..199 LOOP
        v_sql := 'INSERT INTO finance_data_' || i || '
            SELECT 
                nextval(''seq_' || (i+500) || '''), 
                a.account_id,
                CASE WHEN random() < 0.5 
                    THEN ROUND((-random() * (10000 - 100) + 100)::numeric, 2)
                    ELSE ROUND((random() * (10000 - 100) + 100)::numeric, 2)
                END,
                CURRENT_TIMESTAMP - (random() * 365)::integer * interval ''1 day''
            FROM accounts a,
                 generate_series(1, 30) as l(col)';
        EXECUTE v_sql;
    END LOOP;

    -- Populate Operations tables with facility operations data
    FOR i IN 1..199 LOOP
        v_sql := 'INSERT INTO operations_data_' || i || '
            SELECT 
                nextval(''seq_' || (i+700) || '''), 
                f.facility_id,
                CURRENT_TIMESTAMP - (random() * 180)::integer * interval ''1 day'',
                CASE floor(random() * 4 + 1)
                    WHEN 1 THEN ''OPERATIONAL''
                    WHEN 2 THEN ''MAINTENANCE''
                    WHEN 3 THEN ''SHUTDOWN''
                    ELSE ''STARTUP''
                END
            FROM facilities f,
                 generate_series(1, 40) as l(col)';
        EXECUTE v_sql;
    END LOOP;

    -- Populate Customer Service tables with service interaction data
    FOR i IN 1..149 LOOP
        v_sql := 'INSERT INTO service_data_' || i || '
            SELECT 
                nextval(''seq_' || (i+900) || '''), 
                t.ticket_id,
                t.created_at + (random() * 72)::integer * interval ''1 hour'',
                floor(random() * 11 + 1)
            FROM tickets t,
                 generate_series(1, 5) as l(col)
            WHERE t.status = ''CLOSED''';
        EXECUTE v_sql;
    END LOOP;

    COMMIT;
END $$;

-- Analyze tables for better query performance
DO $$
BEGIN
    EXECUTE (
        SELECT string_agg('ANALYZE ' || tablename || ';', ' ')
        FROM pg_tables
        WHERE schemaname = current_schema()
    );
END $$;