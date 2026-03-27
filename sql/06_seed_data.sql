-- =============================================================================
-- LifeOS: Gamified Habit Tracking System (Oracle SQL Version)
-- File: 06_seed_data.sql  |  Static Reference Data
-- =============================================================================

-- ---------------------------------------------------------------------------
-- Badge definitions (criteria must match the constraints in Badges table)
-- ---------------------------------------------------------------------------

BEGIN
    -- We use a small inline procedure here to simulate MySQL's "INSERT IGNORE"
    -- This prevents ORA-00001 (Unique Constraint) errors if the script is run multiple times.
    DECLARE
        PROCEDURE insert_badge(
            p_name VARCHAR2, p_desc VARCHAR2, p_crit VARCHAR2, p_points NUMBER
        ) IS
        BEGIN
            INSERT INTO Badges (badge_name, description, criteria, points_reward)
            VALUES (p_name, p_desc, p_crit, p_points);
        EXCEPTION
            WHEN DUP_VAL_ON_INDEX THEN
                NULL; -- If it exists, skip gracefully
        END;
    BEGIN
        insert_badge('Week Warrior',   'Maintain a streak of 7 days on any habit',      'streak_7',    20);
        insert_badge('Month Master',   'Maintain a streak of 30 days on any habit',     'streak_30',  100);
        insert_badge('Century Club',   'Maintain a streak of 100 days on any habit',    'streak_100', 500);
        insert_badge('First Steps',    'Complete a habit 10 times in total',             'total_10',    15);
        insert_badge('Halfway Hero',   'Complete habits 50 times in total',              'total_50',    50);
        insert_badge('Centurion',      'Complete habits 100 times in total',             'total_100',  100);
        insert_badge('Point Scorer',   'Earn 100 total points',                          'points_100',  10);
        insert_badge('High Scorer',    'Earn 500 total points',                          'points_500',  25);
        insert_badge('Legend',         'Earn 1000 total points',                         'points_1000', 50);
    END;
END;
/
