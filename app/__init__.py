"""
LifeOS – Gamified Habit Tracking System
Flask Backend  |  app/__init__.py
"""

from flask import Flask
from .db import init_db_pool
from .routes import auth, habits, expenses, dashboard, reports
from flask_cors import CORS

def create_app(config=None):
    app = Flask(__name__)
    CORS(app)

    # ── Default config ───────────────────────────────────────────────────────
    app.config.update(
        SECRET_KEY         = "change-me-in-production",
        DB_HOST            = "localhost",
        DB_PORT            = 1521,
        DB_USER            = "system",
        DB_PASSWORD        = "reina",
        DB_NAME            = "XE",
        DB_POOL_SIZE       = 5,
    )

    if config:
        app.config.update(config)

    # ── Database connection pool ─────────────────────────────────────────────
    init_db_pool(app)

    # ── Register blueprints ──────────────────────────────────────────────────
    app.register_blueprint(auth.bp,       url_prefix="/api/auth")
    app.register_blueprint(habits.bp,     url_prefix="/api/habits")
    app.register_blueprint(expenses.bp,   url_prefix="/api/expenses")
    app.register_blueprint(dashboard.bp,  url_prefix="/api/dashboard")
    app.register_blueprint(reports.bp,    url_prefix="/api/reports")

    @app.route("/")
    def index():
        from flask import jsonify
        return jsonify({"message": "Welcome to LifeOS! The Oracle SQL API backend is successfully running.", "status": "online"}), 200

    return app
