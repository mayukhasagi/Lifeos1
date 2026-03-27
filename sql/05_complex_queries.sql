-- =============================================================================
-- LifeOS: Gamified Habit Tracking System (Oracle SQL Version)
-- File: 05_complex_queries.sql  |  Advanced Analytical Queries
-- =============================================================================

-- ===========================================================================
-- QUERY 1: Users who completed ALL their active habits in a given week
-- ===========================================================================
DEFINE target_week = 22;
DEFINE target_year = 2025;

SELECT
    u.user_id,
    u.name,
    COUNT(DISTINCT h.habit_id)    AS total_active_habits,
    COUNT(DISTINCT
        CASE
            WHEN habit_logs_in_week.completed_days >=
                 CASE h.frequency WHEN 'daily' THEN 7 ELSE 1 END
            THEN h.habit_id
        END
    )                              AS habits_fully_completed
FROM Users u
JOIN Habits h ON h.user_id = u.user_id AND h.is_active = 1
LEFT JOIN (
    SELECT
        habit_id,
        COUNT(*) AS completed_days
    FROM Habit_Logs
    WHERE (status = 1 OR completion_count > 0)
      AND EXTRACT(YEAR FROM log_date) = &target_year
      AND TO_NUMBER(TO_CHAR(log_date, 'IW')) = &target_week
    GROUP BY habit_id
) habit_logs_in_week ON habit_logs_in_week.habit_id = h.habit_id
GROUP BY u.user_id, u.name
HAVING
    COUNT(DISTINCT h.habit_id) > 0
    AND COUNT(DISTINCT h.habit_id) =
        COUNT(DISTINCT
            CASE
                WHEN habit_logs_in_week.completed_days >=
                     CASE h.frequency WHEN 'daily' THEN 7 ELSE 1 END
                THEN h.habit_id
            END
        )
ORDER BY u.name;


-- ===========================================================================
-- QUERY 2: Habit with the maximum current streak per user
-- ===========================================================================
SELECT
    u.user_id,
    u.name,
    h.habit_id,
    h.habit_name,
    h.current_streak,
    h.best_streak
FROM Habits h
JOIN Users u ON u.user_id = h.user_id
WHERE h.current_streak = (
    SELECT MAX(h2.current_streak)
    FROM Habits h2
    WHERE h2.user_id = h.user_id
)
AND h.is_active = 1
ORDER BY h.current_streak DESC, u.name;


-- ===========================================================================
-- QUERY 3: Users who are over budget in at least one category
--          BUT maintain >= 80% habit completion this month
-- ===========================================================================
DEFINE current_month = '2025-05';

SELECT
    u.user_id,
    u.name,
    budget_status.over_budget_categories,
    habit_status.completion_pct
FROM Users u
JOIN (
    SELECT
        b.user_id,
        COUNT(*) AS over_budget_categories
    FROM Budgets b
    JOIN (
        SELECT user_id, category,
               TO_CHAR(expense_date, 'YYYY-MM') AS month_year,
               SUM(amount) AS total_spent
        FROM Expenses
        GROUP BY user_id, category, TO_CHAR(expense_date, 'YYYY-MM')
    ) monthly_spend
    ON  monthly_spend.user_id    = b.user_id
    AND monthly_spend.category   = b.category
    AND monthly_spend.month_year = b.month_year
    WHERE b.month_year = '&current_month'
      AND monthly_spend.total_spent > b.monthly_limit
    GROUP BY b.user_id
    HAVING COUNT(*) >= 1
) budget_status ON budget_status.user_id = u.user_id
JOIN (
    SELECT
        h.user_id,
        ROUND(
            100.0 * SUM(
                CASE WHEN hl.status = 1 OR hl.completion_count > 0 THEN 1 ELSE 0 END
            ) / NULLIF(COUNT(hl.log_id), 0),
            1
        ) AS completion_pct
    FROM Habits h
    JOIN Habit_Logs hl ON hl.habit_id = h.habit_id
    WHERE TO_CHAR(hl.log_date, 'YYYY-MM') = '&current_month'
    GROUP BY h.user_id
    HAVING ROUND(
            100.0 * SUM(
                CASE WHEN hl.status = 1 OR hl.completion_count > 0 THEN 1 ELSE 0 END
            ) / NULLIF(COUNT(hl.log_id), 0),
            1
        ) >= 80
) habit_status ON habit_status.user_id = u.user_id
ORDER BY habit_status.completion_pct DESC;


-- ===========================================================================
-- QUERY 4: Top 5 habits by total completions per user
-- ===========================================================================
SELECT
    user_id,
    name,
    habit_id,
    habit_name,
    total_completions,
    user_rank
FROM (
    SELECT
        u.user_id,
        u.name,
        h.habit_id,
        h.habit_name,
        COUNT(CASE WHEN hl.status = 1 OR hl.completion_count > 0 THEN 1 END) AS total_completions,
        RANK() OVER (
            PARTITION BY u.user_id 
            ORDER BY COUNT(CASE WHEN hl.status = 1 OR hl.completion_count > 0 THEN 1 END) DESC
        ) AS user_rank
    FROM Users u
    JOIN Habits h ON u.user_id = h.user_id
    LEFT JOIN Habit_Logs hl ON h.habit_id = hl.habit_id
    GROUP BY u.user_id, u.name, h.habit_id, h.habit_name
    HAVING COUNT(CASE WHEN hl.status = 1 OR hl.completion_count > 0 THEN 1 END) >= 5
)
WHERE user_rank <= 5
ORDER BY user_id, user_rank;


-- ===========================================================================
-- QUERY 5: Expense breakdown with running total per user per month
-- ===========================================================================
SELECT
    e.user_id,
    u.name,
    e.expense_id,
    e.category,
    e.amount,
    e.expense_date,
    (
        SELECT NVL(SUM(e2.amount), 0)
        FROM Expenses e2
        WHERE e2.user_id = e.user_id
          AND TO_CHAR(e2.expense_date, 'YYYY-MM') = TO_CHAR(e.expense_date, 'YYYY-MM')
          AND e2.expense_id <= e.expense_id
    ) AS running_total
FROM Expenses e
JOIN Users u ON u.user_id = e.user_id
ORDER BY e.user_id, e.expense_date, e.expense_id;
