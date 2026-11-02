-----Tables------
CREATE TABLE expense_categories (
    category_id SERIAL PRIMARY KEY,
    category_name VARCHAR(100) NOT NULL UNIQUE
);

CREATE TABLE expense_subcategories (
    subcategory_id SERIAL PRIMARY KEY,
    subcategory_name VARCHAR(100) NOT NULL,
    category_id INT REFERENCES expense_categories(category_id)
);

CREATE TABLE family_members (
    member_id SERIAL PRIMARY KEY,
    member_name VARCHAR(100) NOT NULL
);

CREATE TABLE payment_methods (
    payment_method_id SERIAL PRIMARY KEY,
    payment_method_name VARCHAR(50) NOT NULL UNIQUE
);

CREATE TABLE vendors (
    vendor_id SERIAL PRIMARY KEY,
    vendor_name VARCHAR(150) NOT NULL
);

CREATE TABLE expenses (
    expense_id SERIAL PRIMARY KEY,
    expense_date DATE NOT NULL,
    subcategory_id INT REFERENCES expense_subcategories(subcategory_id),
    member_id INT REFERENCES family_members(member_id),
    vendor_id INT REFERENCES vendors(vendor_id),
    payment_method_id INT REFERENCES payment_methods(payment_method_id),
    amount NUMERIC(12,2) NOT NULL CHECK (amount > 0),
    description TEXT,
    recurring BOOLEAN,
    status VARCHAR(30)
);

CREATE TABLE quarterly_budget (
    budget_id SERIAL PRIMARY KEY,
    category_id INT REFERENCES expense_categories(category_id),
    budget_month DATE NOT NULL,
    budget_amount NUMERIC(12,2) NOT NULL CHECK (budget_amount > 0),
    reason TEXT
);

--Excel Import--

CREATE TABLE expense_staging (
    sr_no INT,
    expense_date DATE,
    category VARCHAR(100),
    subcategory VARCHAR(100),
    amount NUMERIC(12,2),
    member VARCHAR(100),
    vendor VARCHAR(150),
    payment VARCHAR(50),
    recurring VARCHAR(10),
    status VARCHAR(30),
    description TEXT
);

INSERT INTO expenses
(
    expense_date,
    subcategory_id,
    member_id,
    vendor_id,
    payment_method_id,
    amount,
    description,
    recurring,
    status
)
SELECT
    s.expense_date,
    sc.subcategory_id,
    fm.member_id,
    v.vendor_id,
    pm.payment_method_id,
    s.amount,
    s.description,
    CASE
        WHEN LOWER(s.recurring) IN ('true', 'yes')
        THEN TRUE
        ELSE FALSE
    END,
    s.status
FROM expense_staging s
JOIN expense_categories c
    ON LOWER(c.category_name) = LOWER(s.category)
JOIN expense_subcategories sc
    ON sc.category_id = c.category_id
   AND LOWER(sc.subcategory_name) = LOWER(s.subcategory)
LEFT JOIN family_members fm
    ON LOWER(fm.member_name) = LOWER(s.member)
JOIN vendors v
    ON LOWER(v.vendor_name) = LOWER(s.vendor)
JOIN payment_methods pm
    ON LOWER(pm.payment_method_name) = LOWER(s.payment);

---- Data Validation ----

SELECT COUNT(*) AS total_expenses
FROM expenses;

SELECT *
FROM expenses
WHERE amount <= 0;

SELECT
    MIN(expense_date) AS first_expense,
    MAX(expense_date) AS last_expense,
    ROUND(SUM(amount), 2) AS total_expense
FROM expenses;

----------------------------------------------------------------------------------------------------------

----------------------------------------------------------------------------------------------------------

----Basic Analysis
---Total, Average, Minimum, Maximum

SELECT
    COUNT(*) AS total_transactions,
    ROUND(SUM(amount), 2) AS total_expense,
    ROUND(AVG(amount), 2) AS average_expense,
    ROUND(MIN(amount), 2) AS minimum_expense,
    ROUND(MAX(amount), 2) AS maximum_expense
FROM expenses;

--Month-wise Analysis--

SELECT
    EXTRACT(MONTH FROM expense_date) AS month_number,
    TO_CHAR(expense_date, 'Month') AS month,
    COUNT(*) AS total_transactions,
    ROUND(SUM(amount), 2) AS total_expense
FROM expenses
GROUP BY
    EXTRACT(MONTH FROM expense_date),
    TO_CHAR(expense_date, 'Month')
ORDER BY month_number;

----Family Member-wise Analysis--

SELECT
    fm.member_name AS member,
    COUNT(e.expense_id) AS total_transactions,
    ROUND(SUM(e.amount), 2) AS total_expense,
    ROUND(AVG(e.amount), 2) AS average_expense
FROM expenses e
JOIN family_members fm
    ON e.member_id = fm.member_id
GROUP BY fm.member_name
ORDER BY total_expense DESC;

--Payment Method Analysis--

SELECT
    pm.payment_method_name AS payment_method,
    COUNT(e.expense_id) AS total_transactions,
    ROUND(SUM(e.amount), 2) AS total_expense,
    ROUND(AVG(e.amount), 2) AS average_expense
FROM expenses e
JOIN payment_methods pm
    ON e.payment_method_id = pm.payment_method_id
GROUP BY pm.payment_method_name
ORDER BY total_expense DESC;

---Recurring vs Non-Recurring--

SELECT
    CASE
        WHEN recurring = TRUE THEN 'Recurring'
        ELSE 'Non-Recurring'
    END AS expense_type,
    COUNT(*) AS total_transactions,
    ROUND(SUM(amount), 2) AS total_expense,
    ROUND(AVG(amount), 2) AS average_expense
FROM expenses
GROUP BY recurring
ORDER BY total_expense DESC;

------------CASE-----------------

SELECT
    expense_id,
    amount,
    CASE
        WHEN amount < 500 THEN 'Small'
        WHEN amount BETWEEN 500 AND 2000 THEN 'Medium'
        WHEN amount > 2000 AND amount <= 5000 THEN 'High'
        ELSE 'Very High'
    END AS expense_level
FROM expenses
ORDER BY amount DESC;

---UNION / UNION ALL---

SELECT expense_id, amount, 'Essential' AS expense_type
FROM expenses
WHERE amount >= 5000

UNION

SELECT expense_id, amount, 'Discretionary' AS expense_type
FROM expenses
WHERE amount < 5000;

----UNION ALL--------

SELECT expense_id, amount, 'Essential' AS expense_type
FROM expenses
WHERE amount >= 5000

UNION ALL

SELECT expense_id, amount, 'Discretionary' AS expense_type
FROM expenses
WHERE amount < 5000;

---Date Manipulation---

SELECT
    EXTRACT(YEAR FROM expense_date) AS year,
    EXTRACT(MONTH FROM expense_date) AS month_number,
    TO_CHAR(expense_date, 'Month') AS month,
    COUNT(*) AS total_transactions,
    ROUND(SUM(amount), 2) AS total_expense
FROM expenses
GROUP BY
    EXTRACT(YEAR FROM expense_date),
    EXTRACT(MONTH FROM expense_date),
    TO_CHAR(expense_date, 'Month')
ORDER BY year, month_number;

-----Window Function---
SELECT
    c.category_name AS category,
    ROUND(SUM(e.amount), 2) AS category_expense,
    ROUND(
        SUM(e.amount) * 100.0 /
        SUM(SUM(e.amount)) OVER (),
        2
    ) AS percentage_of_total
FROM expenses e
JOIN expense_subcategories sc
    ON e.subcategory_id = sc.subcategory_id
JOIN expense_categories c
    ON sc.category_id = c.category_id
GROUP BY c.category_name
ORDER BY category_expense DESC;

---RANK + PARTITION BY--

SELECT
    c.category_name AS category,
    e.expense_id,
    e.amount,
    RANK() OVER (
        PARTITION BY c.category_name
        ORDER BY e.amount DESC
    ) AS category_rank
FROM expenses e
JOIN expense_subcategories sc
    ON e.subcategory_id = sc.subcategory_id
JOIN expense_categories c
    ON sc.category_id = c.category_id
ORDER BY c.category_name, category_rank;

---Previous Quarter Analysis---

SELECT
    c.category_name AS category,
    ROUND(SUM(e.amount), 2) AS previous_quarter_expense,
    ROUND(SUM(e.amount) / 3, 2) AS monthly_average
FROM expenses e
JOIN expense_subcategories sc
    ON e.subcategory_id = sc.subcategory_id
JOIN expense_categories c
    ON sc.category_id = c.category_id
GROUP BY c.category_name
ORDER BY previous_quarter_expense DESC;

-----Q4 Budget — October, November, December 2026-----

SELECT
    TO_CHAR(qb.budget_month, 'Month YYYY') AS month,
    c.category_name AS category,
    qb.budget_amount,
    qb.reason
FROM quarterly_budget qb
JOIN expense_categories c
    ON qb.category_id = c.category_id
ORDER BY qb.budget_month, c.category_id;

--Monthly Q4 Budget--

SELECT
    TO_CHAR(budget_month, 'Month YYYY') AS month,
    ROUND(SUM(budget_amount), 2) AS monthly_budget
FROM quarterly_budget
GROUP BY budget_month
ORDER BY budget_month;
--October ₹77,600
--November ₹77,600
--December ₹77,600

--Total Q4 Budget--

SELECT
    ROUND(SUM(budget_amount), 2) AS total_q4_budget
FROM quarterly_budget; -------₹2,32,800

---Final Budget Summary--

WITH previous AS (
    SELECT
        c.category_id,
        c.category_name,
        ROUND(SUM(e.amount), 2) AS previous_quarter_expense,
        ROUND(SUM(e.amount) / 3, 2) AS monthly_average
    FROM expenses e
    JOIN expense_subcategories sc
        ON e.subcategory_id = sc.subcategory_id
    JOIN expense_categories c
        ON sc.category_id = c.category_id
    GROUP BY
        c.category_id,
        c.category_name
),
budget AS (
    SELECT
        category_id,
        ROUND(SUM(budget_amount), 2) AS proposed_q4_budget,
        MIN(reason) AS reason
    FROM quarterly_budget
    GROUP BY category_id
)
SELECT
    p.category_name AS category,
    p.previous_quarter_expense,
    p.monthly_average,
    b.proposed_q4_budget,
    ROUND(
        b.proposed_q4_budget -
        p.previous_quarter_expense,
        2
    ) AS adjustment,
    b.reason
FROM previous p
JOIN budget b
    ON p.category_id = b.category_id
ORDER BY b.proposed_q4_budget DESC;

------Budget vs Previous Quarter----

WITH previous AS (
    SELECT
        c.category_id,
        c.category_name,
        ROUND(SUM(e.amount), 2) AS previous_quarter_expense
    FROM expenses e
    JOIN expense_subcategories sc
        ON e.subcategory_id = sc.subcategory_id
    JOIN expense_categories c
        ON sc.category_id = c.category_id
    GROUP BY c.category_id, c.category_name
),
budget AS (
    SELECT
        category_id,
        ROUND(SUM(budget_amount), 2) AS q4_budget
    FROM quarterly_budget
    GROUP BY category_id
)
SELECT
    p.category_name AS category,
    p.previous_quarter_expense,
    b.q4_budget,
    ROUND(
        b.q4_budget - p.previous_quarter_expense,
        2
    ) AS difference,
    CASE
        WHEN b.q4_budget > p.previous_quarter_expense
            THEN 'Budget Increased'
        WHEN b.q4_budget < p.previous_quarter_expense
            THEN 'Budget Decreased'
        ELSE 'No Change'
    END AS budget_status
FROM previous p
JOIN budget b
    ON p.category_id = b.category_id
ORDER BY difference DESC;



















