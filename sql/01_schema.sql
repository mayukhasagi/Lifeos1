-- =============================================================================
-- LifeOS: Gamified Habit Tracking System (Oracle SQL Version)
-- File: 01_schema.sql  |  Database Schema (3NF Normalized)
-- =============================================================================

SET SQLBLANKLINES ON;

-- Clean up existing tables (so it behaves like DROP IF EXISTS)
BEGIN
   EXECUTE IMMEDIATE 'DROP TABLE Budget_Alerts CASCADE CONSTRAINTS';
EXCEPTION WHEN OTHERS THEN NULL; END;
/
BEGIN
   EXECUTE IMMEDIATE 'DROP TABLE Budgets CASCADE CONSTRAINTS';
EXCEPTION WHEN OTHERS THEN NULL; END;
/
BEGIN
   EXECUTE IMMEDIATE 'DROP TABLE Expenses CASCADE CONSTRAINTS';
EXCEPTION WHEN OTHERS THEN NULL; END;
/
BEGIN
   EXECUTE IMMEDIATE 'DROP TABLE User_Badges CASCADE CONSTRAINTS';
EXCEPTION WHEN OTHERS THEN NULL; END;
/
BEGIN
   EXECUTE IMMEDIATE 'DROP TABLE Badges CASCADE CONSTRAINTS';
EXCEPTION WHEN OTHERS THEN NULL; END;
/
BEGIN
   EXECUTE IMMEDIATE 'DROP TABLE Habit_Logs CASCADE CONSTRAINTS';
EXCEPTION WHEN OTHERS THEN NULL; END;
/
BEGIN
   EXECUTE IMMEDIATE 'DROP TABLE Habits CASCADE CONSTRAINTS';
EXCEPTION WHEN OTHERS THEN NULL; END;
/
BEGIN
   EXECUTE IMMEDIATE 'DROP TABLE Users CASCADE CONSTRAINTS';
EXCEPTION WHEN OTHERS THEN NULL; END;
/

-- ---------------------------------------------------------------------------
-- 1. USERS
-- ---------------------------------------------------------------------------
CREATE TABLE Users (
    user_id       NUMBER GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    name          VARCHAR2(100)  NOT NULL,
    email         VARCHAR2(255)  NOT NULL,
    password_hash VARCHAR2(255)  NOT NULL,
    points        NUMBER         DEFAULT 0 NOT NULL,
    created_at    TIMESTAMP      DEFAULT CURRENT_TIMESTAMP NOT NULL,
    CONSTRAINT uq_users_email UNIQUE (email)
);

-- ---------------------------------------------------------------------------
-- 2. HABITS
-- ---------------------------------------------------------------------------
CREATE TABLE Habits (
    habit_id      NUMBER GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    user_id       NUMBER         NOT NULL,
    habit_name    VARCHAR2(150)  NOT NULL,
    frequency     VARCHAR2(20)   DEFAULT 'daily' NOT NULL,
    target_count  NUMBER         DEFAULT 1 NOT NULL,
    habit_type    VARCHAR2(20)   DEFAULT 'binary' NOT NULL,
    current_streak NUMBER        DEFAULT 0 NOT NULL,
    best_streak   NUMBER         DEFAULT 0 NOT NULL,
    is_active     NUMBER(1)      DEFAULT 1 NOT NULL,
    created_at    TIMESTAMP      DEFAULT CURRENT_TIMESTAMP NOT NULL,
    CONSTRAINT fk_habits_user FOREIGN KEY (user_id) REFERENCES Users(user_id) ON DELETE CASCADE,
    CONSTRAINT chk_habit_freq CHECK (frequency IN ('daily', 'weekly')),
    CONSTRAINT chk_habit_type CHECK (habit_type IN ('binary', 'count'))
);

CREATE INDEX idx_habits_user ON Habits(user_id);
CREATE INDEX idx_habits_active ON Habits(user_id, is_active);

-- ---------------------------------------------------------------------------
-- 3. HABIT_LOGS
-- ---------------------------------------------------------------------------
CREATE TABLE Habit_Logs (
    log_id            NUMBER GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    habit_id          NUMBER         NOT NULL,
    log_date          DATE           NOT NULL,
    status            NUMBER(1)      DEFAULT 0 NOT NULL,
    completion_count  NUMBER         DEFAULT 0 NOT NULL,
    logged_at         TIMESTAMP      DEFAULT CURRENT_TIMESTAMP NOT NULL,
    CONSTRAINT fk_logs_habit FOREIGN KEY (habit_id) REFERENCES Habits(habit_id) ON DELETE CASCADE,
    CONSTRAINT uq_log_habit_date UNIQUE (habit_id, log_date)
);

CREATE INDEX idx_logs_habit_date ON Habit_Logs(habit_id, log_date);
CREATE INDEX idx_logs_date ON Habit_Logs(log_date);

-- ---------------------------------------------------------------------------
-- 4. BADGES
-- ---------------------------------------------------------------------------
CREATE TABLE Badges (
    badge_id    NUMBER GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    badge_name  VARCHAR2(100) NOT NULL,
    description VARCHAR2(255) NOT NULL,
    criteria    VARCHAR2(50)  NOT NULL,
    points_reward NUMBER      DEFAULT 0 NOT NULL,
    CONSTRAINT uq_badge_name UNIQUE (badge_name),
    CONSTRAINT chk_badge_criteria CHECK (
        criteria IN (
            'streak_7', 'streak_30', 'streak_100',
            'total_10', 'total_50', 'total_100',
            'points_100', 'points_500', 'points_1000'
        )
    )
);

-- ---------------------------------------------------------------------------
-- 5. USER_BADGES
-- ---------------------------------------------------------------------------
CREATE TABLE User_Badges (
    user_id      NUMBER    NOT NULL,
    badge_id     NUMBER    NOT NULL,
    awarded_date TIMESTAMP DEFAULT CURRENT_TIMESTAMP NOT NULL,
    PRIMARY KEY (user_id, badge_id),
    CONSTRAINT fk_ub_user FOREIGN KEY (user_id) REFERENCES Users(user_id) ON DELETE CASCADE,
    CONSTRAINT fk_ub_badge FOREIGN KEY (badge_id) REFERENCES Badges(badge_id) ON DELETE CASCADE
);

-- ---------------------------------------------------------------------------
-- 6. EXPENSES
-- ---------------------------------------------------------------------------
CREATE TABLE Expenses (
    expense_id   NUMBER GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    user_id      NUMBER         NOT NULL,
    category     VARCHAR2(80)   NOT NULL,
    amount       NUMBER(10, 2)  NOT NULL,
    note         VARCHAR2(255)  NULL,
    expense_date DATE           NOT NULL,
    created_at   TIMESTAMP      DEFAULT CURRENT_TIMESTAMP NOT NULL,
    CONSTRAINT fk_expenses_user FOREIGN KEY (user_id) REFERENCES Users(user_id) ON DELETE CASCADE,
    CONSTRAINT chk_exp_amount CHECK (amount > 0)
);

CREATE INDEX idx_expenses_user_cat  ON Expenses(user_id, category);
CREATE INDEX idx_expenses_user_date ON Expenses(user_id, expense_date);

-- ---------------------------------------------------------------------------
-- 7. BUDGETS
-- ---------------------------------------------------------------------------
CREATE TABLE Budgets (
    budget_id     NUMBER GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    user_id       NUMBER         NOT NULL,
    category      VARCHAR2(80)   NOT NULL,
    monthly_limit NUMBER(10, 2)  NOT NULL,
    month_year    VARCHAR2(7)    NOT NULL,
    CONSTRAINT fk_budgets_user FOREIGN KEY (user_id) REFERENCES Users(user_id) ON DELETE CASCADE,
    CONSTRAINT chk_bud_limit CHECK (monthly_limit > 0),
    CONSTRAINT uq_bud_user_cat_mon UNIQUE (user_id, category, month_year)
);

CREATE INDEX idx_budgets_user ON Budgets(user_id);

-- ---------------------------------------------------------------------------
-- 8. BUDGET_ALERTS
-- ---------------------------------------------------------------------------
CREATE TABLE Budget_Alerts (
    alert_id        NUMBER GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    user_id         NUMBER         NOT NULL,
    category        VARCHAR2(80)   NOT NULL,
    month_year      VARCHAR2(7)    NOT NULL,
    budget_limit    NUMBER(10, 2)  NOT NULL,
    total_spent     NUMBER(10, 2)  NOT NULL,
    overage         NUMBER(10, 2)  NOT NULL,
    triggered_at    TIMESTAMP      DEFAULT CURRENT_TIMESTAMP NOT NULL,
    expense_id      NUMBER         NOT NULL,
    CONSTRAINT fk_alerts_user FOREIGN KEY (user_id) REFERENCES Users(user_id) ON DELETE CASCADE,
    CONSTRAINT fk_alerts_expense FOREIGN KEY (expense_id) REFERENCES Expenses(expense_id) ON DELETE CASCADE
);
