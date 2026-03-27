-- =============================================================================
-- LifeOS: Gamified Habit Tracking System (Oracle SQL Version)
-- File: 02_triggers.sql  |  All Database Triggers
-- =============================================================================

-- ---------------------------------------------------------------------------
-- TRIGGER 1: trg_after_habit_log_insert
--
-- Fires AFTER a row is inserted into Habit_Logs.
-- Implemented as a Compound Trigger to avoid the mutating table error (ORA-04091).
-- ---------------------------------------------------------------------------
CREATE OR REPLACE TRIGGER trg_after_habit_log_insert
FOR INSERT ON Habit_Logs
COMPOUND TRIGGER

    TYPE habit_log_rt IS RECORD (
        habit_id NUMBER,
        status NUMBER,
        completion_count NUMBER
    );
    TYPE habit_log_aat IS TABLE OF habit_log_rt INDEX BY PLS_INTEGER;
    v_logs habit_log_aat;
    v_idx PLS_INTEGER := 0;

    AFTER EACH ROW IS
    BEGIN
        IF :NEW.status = 1 OR :NEW.completion_count > 0 THEN
            v_idx := v_idx + 1;
            v_logs(v_idx).habit_id := :NEW.habit_id;
            v_logs(v_idx).status := :NEW.status;
            v_logs(v_idx).completion_count := :NEW.completion_count;
        END IF;
    END AFTER EACH ROW;

    AFTER STATEMENT IS
        v_streak    NUMBER := 0;
        v_user_id   NUMBER;
        v_prev_date DATE;
        v_gap_found NUMBER;
    BEGIN
        FOR i IN 1 .. v_logs.COUNT LOOP
            -- Walk back through logs for this habit ordered descending.
            v_streak := 0;
            v_prev_date := NULL;
            v_gap_found := 0;
            
            FOR rec IN (
                SELECT log_date
                FROM Habit_Logs
                WHERE habit_id = v_logs(i).habit_id
                  AND (status = 1 OR completion_count > 0)
                ORDER BY log_date DESC
            )
            LOOP
                IF v_gap_found = 1 THEN
                    EXIT;
                END IF;
                
                IF v_prev_date IS NULL THEN
                    v_prev_date := rec.log_date;
                    v_streak := 1;
                ELSIF (v_prev_date - rec.log_date) = 1 THEN
                    v_prev_date := rec.log_date;
                    v_streak := v_streak + 1;
                ELSE
                    v_gap_found := 1;
                END IF;
            END LOOP;

            -- Update habit streaks
            UPDATE Habits
            SET current_streak = v_streak,
                best_streak    = GREATEST(best_streak, v_streak)
            WHERE habit_id = v_logs(i).habit_id
            RETURNING user_id INTO v_user_id;

            -- Award points and check badges
            sp_award_points(v_user_id, v_logs(i).habit_id, v_streak);
            sp_check_and_award_badges(v_user_id);
        END LOOP;
    END AFTER STATEMENT;

END trg_after_habit_log_insert;
/


-- ---------------------------------------------------------------------------
-- TRIGGER 2: trg_after_expense_insert
--
-- Fires AFTER a row is inserted into Expenses.
-- Implemented as a Compound Trigger to evaluate total_spend without ORA-04091.
-- ---------------------------------------------------------------------------
CREATE OR REPLACE TRIGGER trg_after_expense_insert
FOR INSERT ON Expenses
COMPOUND TRIGGER

    TYPE expense_rt IS RECORD (
        expense_id   NUMBER,
        user_id      NUMBER,
        category     VARCHAR2(80),
        amount       NUMBER(10, 2),
        expense_date DATE
    );
    TYPE expense_aat IS TABLE OF expense_rt INDEX BY PLS_INTEGER;
    v_expenses expense_aat;
    v_idx PLS_INTEGER := 0;

    AFTER EACH ROW IS
    BEGIN
        v_idx := v_idx + 1;
        v_expenses(v_idx).expense_id   := :NEW.expense_id;
        v_expenses(v_idx).user_id      := :NEW.user_id;
        v_expenses(v_idx).category     := :NEW.category;
        v_expenses(v_idx).amount       := :NEW.amount;
        v_expenses(v_idx).expense_date := :NEW.expense_date;
    END AFTER EACH ROW;

    AFTER STATEMENT IS
        v_limit      NUMBER(10,2);
        v_spent      NUMBER(10,2);
        v_month_year VARCHAR2(7);
    BEGIN
        FOR i IN 1 .. v_expenses.COUNT LOOP
            v_month_year := TO_CHAR(v_expenses(i).expense_date, 'YYYY-MM');

            BEGIN
                SELECT monthly_limit INTO v_limit
                FROM Budgets
                WHERE user_id    = v_expenses(i).user_id
                  AND category   = v_expenses(i).category
                  AND month_year = v_month_year;
            EXCEPTION
                WHEN NO_DATA_FOUND THEN v_limit := NULL;
            END;

            IF v_limit IS NOT NULL THEN
                SELECT NVL(SUM(amount), 0) INTO v_spent
                FROM Expenses
                WHERE user_id = v_expenses(i).user_id
                  AND category = v_expenses(i).category
                  AND TO_CHAR(expense_date, 'YYYY-MM') = v_month_year;

                IF v_spent > v_limit THEN
                    INSERT INTO Budget_Alerts
                        (user_id, category, month_year, budget_limit, total_spent, overage, expense_id)
                    VALUES
                        (v_expenses(i).user_id, v_expenses(i).category, v_month_year,
                         v_limit, v_spent, v_spent - v_limit, v_expenses(i).expense_id);
                END IF;
            END IF;
        END LOOP;
    END AFTER STATEMENT;

END trg_after_expense_insert;
/
