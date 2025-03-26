-- Set search path to use the new schema
SET search_path TO public;

-- Employee Hierarchy View
CREATE OR REPLACE VIEW vw_employee_hierarchy AS
WITH RECURSIVE emp_hierarchy (employee_id, first_name, last_name, manager_id, dept_id, hierarchy_level, path) AS (
  -- Base case: employees with no manager (top level)
  SELECT 
    employee_id,
    first_name,
    last_name,
    manager_id,
    dept_id,
    1 as hierarchy_level,
    CAST(employee_id AS TEXT) as path
  FROM employees
  WHERE manager_id IS NULL
  
  UNION ALL
  
  -- Recursive case: employees with managers
  SELECT 
    e.employee_id,
    e.first_name,
    e.last_name,
    e.manager_id,
    e.dept_id,
    h.hierarchy_level + 1,
    h.path || ',' || CAST(e.employee_id AS TEXT)
  FROM employees e
  JOIN emp_hierarchy h ON e.manager_id = h.employee_id
)
SELECT 
  eh.employee_id,
  eh.first_name,
  eh.last_name,
  eh.manager_id,
  d.name as department_name,
  eh.hierarchy_level,
  eh.path as reporting_path
FROM emp_hierarchy eh
JOIN departments d ON eh.dept_id = d.dept_id
ORDER BY eh.path;

-- Sales Performance Dashboard View
CREATE OR REPLACE VIEW vw_sales_performance AS
SELECT 
    o.employee_id,
    e.first_name || ' ' || e.last_name as employee_name,
    d.name as department,
    COUNT(o.order_id) as total_orders,
    SUM(o.total_amount) as total_sales,
    AVG(o.total_amount) as avg_order_value,
    COUNT(DISTINCT o.customer_id) as unique_customers,
    ROUND(SUM(o.total_amount) / NULLIF(COUNT(DISTINCT o.customer_id), 0), 2) as revenue_per_customer,
    MIN(o.order_date) as first_order,
    MAX(o.order_date) as last_order
FROM orders o
JOIN employees e ON o.employee_id = e.employee_id
JOIN departments d ON e.dept_id = d.dept_id
GROUP BY o.employee_id, e.first_name, e.last_name, d.name;

-- Customer Lifetime Value View
CREATE OR REPLACE VIEW vw_customer_lifetime_value AS
SELECT 
    c.customer_id,
    c.name as customer_name,
    COUNT(DISTINCT o.order_id) as total_orders,
    SUM(o.total_amount) as total_spent,
    AVG(o.total_amount) as avg_order_value,
    MIN(o.order_date) as first_purchase,
    MAX(o.order_date) as last_purchase,
    ROUND(SUM(o.total_amount) / NULLIF(EXTRACT(MONTH FROM AGE(MAX(o.order_date), MIN(o.order_date))), 0), 2) as avg_monthly_spend,
    COUNT(DISTINCT CAST(EXTRACT(MONTH FROM o.order_date) AS TEXT) || '-' || CAST(EXTRACT(YEAR FROM o.order_date) AS TEXT)) as active_months
FROM customers c
LEFT JOIN orders o ON c.customer_id = o.customer_id
GROUP BY c.customer_id, c.name;

-- Product Performance Analysis View
CREATE OR REPLACE VIEW vw_product_performance AS
SELECT 
    p.product_id,
    p.name as product_name,
    pc.name as category_name,
    COUNT(oi.order_id) as times_ordered,
    SUM(oi.quantity) as total_quantity_sold,
    SUM(oi.quantity * oi.unit_price) as total_revenue,
    AVG(oi.unit_price) as avg_selling_price,
    SUM(oi.discount_amount) as total_discounts,
    ROUND(SUM(oi.discount_amount) / NULLIF(SUM(oi.quantity * oi.unit_price), 0) * 100, 2) as discount_percentage
FROM products p
JOIN product_categories pc ON p.category_id = pc.category_id
LEFT JOIN order_items oi ON p.product_id = oi.product_id
GROUP BY p.product_id, p.name, pc.name;

-- Customer Service Satisfaction Analysis View
CREATE OR REPLACE VIEW vw_service_satisfaction AS
WITH service_metrics AS (
    SELECT 
        t.ticket_id,
        t.customer_id,
        AVG(sd.satisfaction_score) as avg_satisfaction,
        COUNT(sd.id) as interactions,
        MAX(sd.resolution_time) - MIN(t.created_at) as resolution_duration
    FROM tickets t
    LEFT JOIN service_data_1 sd ON t.ticket_id = sd.ticket_id
    GROUP BY t.ticket_id, t.customer_id
)
SELECT 
    c.customer_id,
    c.name as customer_name,
    COUNT(sm.ticket_id) as total_tickets,
    ROUND(AVG(sm.avg_satisfaction), 2) as avg_satisfaction_score,
    ROUND(AVG(sm.interactions), 2) as avg_interactions_per_ticket,
    ROUND(AVG(EXTRACT(HOUR FROM sm.resolution_duration)), 2) as avg_resolution_hours
FROM customers c
LEFT JOIN service_metrics sm ON c.customer_id = sm.customer_id
GROUP BY c.customer_id, c.name;

-- Financial Health Dashboard View
CREATE OR REPLACE VIEW vw_financial_health AS
SELECT 
    a.account_id,
    c.name as customer_name,
    a.account_type,
    a.balance as current_balance,
    COUNT(t.transaction_id) as total_transactions,
    SUM(CASE WHEN t.transaction_type IN ('PURCHASE', 'WITHDRAWAL') THEN -t.amount ELSE t.amount END) as net_flow,
    SUM(CASE WHEN t.transaction_type = 'PURCHASE' THEN t.amount ELSE 0 END) as total_purchases,
    SUM(CASE WHEN t.transaction_type = 'REFUND' THEN t.amount ELSE 0 END) as total_refunds,
    ROUND(SUM(CASE WHEN t.transaction_type = 'REFUND' THEN t.amount ELSE 0 END) / 
          NULLIF(SUM(CASE WHEN t.transaction_type = 'PURCHASE' THEN t.amount ELSE 0 END), 0) * 100, 2) as refund_rate
FROM accounts a
JOIN customers c ON a.customer_id = c.customer_id
LEFT JOIN transactions t ON a.account_id = t.account_id
GROUP BY a.account_id, c.name, a.account_type, a.balance;

-- Inventory Health View
CREATE OR REPLACE VIEW vw_inventory_health AS
WITH inventory_status AS (
    SELECT 
        product_id,
        SUM(quantity) as total_quantity
    FROM inventory_data_1  -- Using first inventory table as example
    GROUP BY product_id
)
SELECT 
    p.product_id,
    p.name as product_name,
    pc.name as category_name,
    i.total_quantity as current_stock,
    COUNT(oi.order_id) as order_count,
    SUM(oi.quantity) as total_demand,
    ROUND(i.total_quantity / NULLIF(AVG(oi.quantity), 0), 2) as stock_to_demand_ratio,
    CASE 
        WHEN i.total_quantity = 0 THEN 'Out of Stock'
        WHEN i.total_quantity < AVG(oi.quantity) THEN 'Low Stock'
        ELSE 'Healthy'
    END as stock_status
FROM products p
JOIN product_categories pc ON p.category_id = pc.category_id
LEFT JOIN inventory_status i ON p.product_id = i.product_id
LEFT JOIN order_items oi ON p.product_id = oi.product_id
GROUP BY p.product_id, p.name, pc.name, i.total_quantity;

-- Operations Efficiency View
CREATE OR REPLACE VIEW vw_operations_efficiency AS
WITH operation_gaps AS (
    SELECT 
        f.facility_id,
        f.name as facility_name,
        f.location,
        od.operation_date,
        LAG(od.operation_date) OVER (PARTITION BY f.facility_id ORDER BY od.operation_date) as prev_operation_date,
        od.status
    FROM facilities f
    LEFT JOIN operations_data_1 od ON f.facility_id = od.facility_id
)
SELECT 
    facility_id,
    facility_name,
    location,
    COUNT(operation_date) as total_operations,
    SUM(CASE WHEN status = 'COMPLETED' THEN 1 ELSE 0 END) as completed_operations,
    ROUND(SUM(CASE WHEN status = 'COMPLETED' THEN 1 ELSE 0 END) * 100.0 / NULLIF(COUNT(operation_date), 0), 2) as completion_rate,
    ROUND(AVG(
        CASE 
            WHEN prev_operation_date IS NOT NULL 
            THEN EXTRACT(HOUR FROM (operation_date - prev_operation_date))
        END
    ), 2) as avg_hours_between_ops
FROM operation_gaps
GROUP BY facility_id, facility_name, location;

-- Create materialized views for better performance
-- Note: PostgreSQL supports materialized views which can improve query performance

-- Employee Overview
CREATE MATERIALIZED VIEW IF NOT EXISTS mv_employee_overview AS
SELECT 
    e.employee_id,
    e.first_name,
    e.last_name,
    d.name AS department,
    jt.title_name,
    eg.grade_name,
    e.salary,
    e.status
FROM employees e
LEFT JOIN departments d ON e.dept_id = d.dept_id
LEFT JOIN job_titles jt ON e.title_id = jt.title_id
LEFT JOIN employee_grades eg ON e.grade_id = eg.grade_id
WITH DATA;

-- Sales Summary
CREATE MATERIALIZED VIEW IF NOT EXISTS mv_sales_summary AS
WITH all_sales AS (
    SELECT customer_id, amount, transaction_date 
    FROM sales_data_1
    UNION ALL
    SELECT customer_id, amount, transaction_date 
    FROM sales_data_2
    -- Add more UNION ALLs as needed
)
SELECT 
    c.customer_id,
    c.name AS customer_name,
    COUNT(*) AS total_transactions,
    SUM(s.amount) AS total_amount,
    AVG(s.amount) AS avg_amount,
    MAX(s.transaction_date) AS last_transaction
FROM customers c
LEFT JOIN all_sales s ON c.customer_id = s.customer_id
GROUP BY c.customer_id, c.name
WITH DATA;

-- Product Performance
CREATE MATERIALIZED VIEW IF NOT EXISTS mv_product_performance AS
SELECT 
    p.product_id,
    p.name AS product_name,
    pc.name AS category_name,
    COUNT(oi.item_id) AS total_orders,
    SUM(oi.quantity) AS total_quantity,
    SUM(oi.quantity * oi.unit_price) AS total_revenue
FROM products p
LEFT JOIN product_categories pc ON p.category_id = pc.category_id
LEFT JOIN order_items oi ON p.product_id = oi.product_id
GROUP BY p.product_id, p.name, pc.name
WITH DATA;

-- Create indexes on materialized views
CREATE INDEX IF NOT EXISTS idx_mv_employee_overview_id ON mv_employee_overview(employee_id);
CREATE INDEX IF NOT EXISTS idx_mv_sales_summary_customer ON mv_sales_summary(customer_id);
CREATE INDEX IF NOT EXISTS idx_mv_product_performance_id ON mv_product_performance(product_id);

-- Refresh function for materialized views
CREATE OR REPLACE FUNCTION refresh_materialized_views() RETURNS void AS $$
BEGIN
    REFRESH MATERIALIZED VIEW mv_employee_overview;
    REFRESH MATERIALIZED VIEW mv_sales_summary;
    REFRESH MATERIALIZED VIEW mv_product_performance;
END;
$$ LANGUAGE plpgsql;