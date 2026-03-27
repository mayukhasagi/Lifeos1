-- =============================================================================
-- LifeOS: Gamified Habit Tracking System (Oracle SQL Version)
-- File: 03_procedures.sql  |  Stored Procedures
-- =============================================================================

-- ---------------------------------------------------------------------------
-- PROCEDURE 1: sp_award_points
-- ---------------------------------------------------------------------------
CREATE OR REPLACE PROCEDURE sp_award_points(
    p_user_id  IN NUMBER,
    p_habit_id IN NUMBER,
    p_streak   IN NUMBER
) IS
    v_base_points    NUMBER := 10;
    v_bonus_points   NUMBER := 0;
    v_total_points   NUMBER := 0;
    v_habit_type     VARCHAR2(20);
    v_target         NUMBER;
    v_last_count     NUMBER;
BEGIN
    -- Fetch habit meta
    SELECT habit_type, target_count INTO v_habit_type, v_target
    FROM Habits
    WHERE habit_id = p_habit_id;

    -- For count-based habits scale base points proportionally
    IF v_habit_type = 'count' THEN
        BEGIN
            SELECT completion_count INTO v_last_count
            FROM (
                SELECT completion_count 
                FROM Habit_Logs
                WHERE habit_id = p_habit_id
                ORDER BY log_date DESC
            )
            WHERE ROWNUM = 1;

            v_base_points := FLOOR(10 * LEAST(v_last_count, v_target) / v_target);
        EXCEPTION
            WHEN NO_DATA_FOUND THEN
                v_last_count := 0;
                v_base_points := 0;
        END;
    END IF;

    -- Streak bonuses (cumulative logic translated)
    IF p_streak >= 100 THEN
        v_bonus_points := 25;
    ELSIF p_streak >= 30 THEN
        v_bonus_points := 10;
    ELSIF p_streak >= 7 THEN
        v_bonus_points := 5;
    END IF;

    v_total_points := v_base_points + v_bonus_points;

    -- Apply to user
    UPDATE Users
    SET points = points + v_total_points
    WHERE user_id = p_user_id;
END;
/


-- ---------------------------------------------------------------------------
-- PROCEDURE 2: sp_check_and_award_badges
-- ---------------------------------------------------------------------------
CREATE OR REPLACE PROCEDURE sp_check_and_award_badges(
    p_user_id IN NUMBER
) IS
    v_points         NUMBER := 0;
    v_max_streak     NUMBER := 0;
    v_total_logs     NUMBER := 0;
BEGIN
    -- Snapshot current user stats
    SELECT points INTO v_points FROM Users WHERE user_id = p_user_id;
    SELECT NVL(MAX(current_streak), 0) INTO v_max_streak FROM Habits WHERE user_id = p_user_id;

    SELECT COUNT(*) INTO v_total_logs
    FROM Habit_Logs hl
    JOIN Habits h ON h.habit_id = hl.habit_id
    WHERE h.user_id = p_user_id
      AND (hl.status = 1 OR hl.completion_count > 0);

    -- Nested block to safely insert and ignore duplicate values
    DECLARE
        PROCEDURE award_badge(p_criteria VARCHAR2) IS
        BEGIN
            FOR rec IN (SELECT badge_id FROM Badges WHERE criteria = p_criteria) LOOP
                BEGIN
                    INSERT INTO User_Badges (user_id, badge_id) VALUES (p_user_id, rec.badge_id);
                EXCEPTION WHEN DUP_VAL_ON_INDEX THEN
                    NULL; -- Silently ignore duplicates
                END;
            END LOOP;
        END award_badge;
    BEGIN
        -- Streak badges
        IF v_max_streak >= 7 THEN award_badge('streak_7'); END IF;
        IF v_max_streak >= 30 THEN award_badge('streak_30'); END IF;
        IF v_max_streak >= 100 THEN award_badge('streak_100'); END IF;

        -- Completion badges
        IF v_total_logs >= 10 THEN award_badge('total_10'); END IF;
        IF v_total_logs >= 50 THEN award_badge('total_50'); END IF;
        IF v_total_logs >= 100 THEN award_badge('total_100'); END IF;

        -- Points badges
        IF v_points >= 100 THEN award_badge('points_100'); END IF;
        IF v_points >= 500 THEN award_badge('points_500'); END IF;
        IF v_points >= 1000 THEN award_badge('points_1000'); END IF;
    END;
END;
/


-- ---------------------------------------------------------------------------
-- PROCEDURE 3: sp_log_habit
-- Safe delete + insert. Oracle doesn't have INSERT IGNORE.
-- ---------------------------------------------------------------------------
CREATE OR REPLACE PROCEDURE sp_log_habit(
    p_habit_id         IN NUMBER,
    p_log_date         IN DATE,
    p_status           IN NUMBER,
    p_completion_count IN NUMBER
) IS
BEGIN
    DELETE FROM Habit_Logs WHERE habit_id = p_habit_id AND log_date = p_log_date;
    INSERT INTO Habit_Logs (habit_id, log_date, status, completion_count)
    VALUES (p_habit_id, p_log_date, p_status, p_completion_count);
END;
/
