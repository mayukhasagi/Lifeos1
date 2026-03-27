"""
LifeOS – db.py
Thin wrapper around oracledb connection pool.
All query execution is done via raw SQL — no ORM.
"""

import oracledb
from flask import g, current_app

_pool = None

def init_db_pool(app):
    """Called once at app startup to create the connection pool."""
    global _pool
    # oracledb runs in Thin mode by default (no thick client required)
    dsn = f"{app.config['DB_HOST']}:{app.config['DB_PORT']}/{app.config['DB_NAME']}"
    _pool = oracledb.create_pool(
        user=app.config["DB_USER"],
        password=app.config["DB_PASSWORD"],
        dsn=dsn,
        min=2,
        max=app.config["DB_POOL_SIZE"],
        increment=1
    )


def get_conn():
    """
    Return (or create) a per-request connection stored on Flask's `g`.
    """
    if "db_conn" not in g:
        g.db_conn = _pool.acquire()
        g.db_conn.autocommit = False
    return g.db_conn


def close_conn(e=None):
    conn = g.pop("db_conn", None)
    if conn is not None:
        _pool.release(conn)


def _convert_sql_for_oracle(sql: str) -> str:
    """
    Naively convert %s parameters into Oracle's positional :1, :2 parameters.
    Since we don't have %s inside string literals in this app, simple split is safe.
    """
    parts = sql.split('%s')
    if len(parts) == 1:
        return sql
    new_sql = parts[0]
    for i in range(1, len(parts)):
        new_sql += f":{i}" + parts[i]
    return new_sql


def query(sql: str, params=None, *, fetch_one=False, fetch_all=True,
          commit=False, call_proc=False, out_id_type=None):
    """
    Generic SQL execution helper for Oracle.

    Args:
        sql         : Raw SQL string (use %s placeholders - will be auto-converted).
        params      : Tuple / list of parameters.
        fetch_one   : Return single row dict.
        fetch_all   : Return list of row dicts (default True).
        commit      : Commit after execution.
        call_proc   : Use callproc() instead of execute().
        out_id_type : 'NUMBER' or None. If set, creates a bind var
                      to capture RETURNING id INTO :out_id
    """
    conn   = get_conn()
    cursor = conn.cursor()
    
    try:
        sql = _convert_sql_for_oracle(sql)
        proc_params = list(params) if params else []
        
        if out_id_type:
            out_var = cursor.var(oracledb.NUMBER)
            proc_params.append(out_var)
        
        if call_proc:
            cursor.callproc(sql, proc_params)
            if commit:
                conn.commit()
            return None # We don't fetch from stored procs in our app
        else:
            cursor.execute(sql, proc_params)
            
            # Setup rowfactory to get dictionaries with lowercase keys
            if cursor.description:
                columns = [col[0].lower() for col in cursor.description]
                cursor.rowfactory = lambda *args: dict(zip(columns, args))
                
            if commit:
                conn.commit()
                if out_id_type:
                    return int(out_var.getvalue()[0])
                return None
                
            if fetch_one:
                return cursor.fetchone()
            if fetch_all:
                if cursor.description:
                    return cursor.fetchall()
                return []
    except oracledb.Error as exc:
        conn.rollback()
        raise exc
    finally:
        cursor.close()
