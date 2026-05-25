import base64
import json
import os
import time
import uuid
from datetime import datetime, timezone

import ydb


BACKEND_VERSION = os.getenv("BACKEND_VERSION", "1.0.0")
BACKEND_REPLICA = os.getenv("BACKEND_REPLICA", "local")
TABLE_NAME = os.getenv("TABLE_NAME", "messages")


def json_response(status_code, body):
    return {
        "statusCode": status_code,
        "headers": {
            "Content-Type": "application/json; charset=utf-8",
            "Cache-Control": "no-store",
        },
        "isBase64Encoded": False,
        "body": json.dumps(body, ensure_ascii=False),
    }


def meta():
    return {
        "backendVersion": BACKEND_VERSION,
        "backendReplica": BACKEND_REPLICA,
    }


def get_config():
    endpoint = os.getenv("endpoint")
    database = os.getenv("database")

    if not endpoint or not database:
        raise RuntimeError("Environment variables endpoint and database are required")

    credentials = ydb.construct_credentials_from_environ()
    return ydb.DriverConfig(endpoint, database, credentials=credentials)


def with_session(action):
    config = get_config()

    with ydb.Driver(config) as driver:
        driver.wait(timeout=8)
        session = driver.table_client.session().create()
        return action(session)


def create_schema():
    query = f"""
    CREATE TABLE IF NOT EXISTS `{TABLE_NAME}`
    (
        id Utf8,
        author Utf8,
        message Utf8,
        created_at Utf8,
        backend_replica Utf8,
        PRIMARY KEY (id)
    );
    """

    def action(session):
        session.execute_scheme(query)

    with_session(action)


def execute_query(query, params=None):
    def action(session):
        prepared = session.prepare(query)
        return session.transaction(ydb.SerializableReadWrite()).execute(
            prepared,
            params or {},
            commit_tx=True,
        )

    return with_session(action)


def parse_body(event):
    body = event.get("body") or ""

    if event.get("isBase64Encoded"):
        body = base64.b64decode(body).decode("utf-8")

    if not body:
        return {}

    return json.loads(body)


def list_messages():
    query = f"""
    SELECT id, author, message, created_at, backend_replica
    FROM `{TABLE_NAME}`
    ORDER BY created_at DESC
    LIMIT 50;
    """

    result_sets = execute_query(query)
    rows = result_sets[0].rows if result_sets else []

    messages = [
        {
            "id": row.id,
            "author": row.author,
            "message": row.message,
            "createdAt": row.created_at,
            "backendReplica": row.backend_replica,
        }
        for row in rows
    ]

    return json_response(200, {"messages": messages, "meta": meta()})


def clean_text(value, fallback, limit):
    text = str(value or "").strip()
    if not text:
        text = fallback
    return text[:limit]


def create_message(event):
    payload = parse_body(event)
    author = clean_text(payload.get("author"), "Аноним", 40)
    message = clean_text(payload.get("message"), "", 500)

    if not message:
        return json_response(400, {"error": "Message is required", "meta": meta()})

    message_id = f"{int(time.time() * 1000)}-{uuid.uuid4().hex[:12]}"
    created_at = datetime.now(timezone.utc).isoformat()

    query = f"""
    DECLARE $id AS Utf8;
    DECLARE $author AS Utf8;
    DECLARE $message AS Utf8;
    DECLARE $created_at AS Utf8;
    DECLARE $backend_replica AS Utf8;

    UPSERT INTO `{TABLE_NAME}` (id, author, message, created_at, backend_replica)
    VALUES ($id, $author, $message, $created_at, $backend_replica);
    """

    execute_query(query, {
        "$id": message_id,
        "$author": author,
        "$message": message,
        "$created_at": created_at,
        "$backend_replica": BACKEND_REPLICA,
    })

    return json_response(201, {
        "message": {
            "id": message_id,
            "author": author,
            "message": message,
            "createdAt": created_at,
            "backendReplica": BACKEND_REPLICA,
        },
        "meta": meta(),
    })


def route_http(event):
    method = event.get("httpMethod") or event.get("method") or "GET"
    path = event.get("path") or event.get("url") or "/"

    if path.endswith("?"):
        path = path[:-1]

    if path == "/api/health" and method == "GET":
        return json_response(200, {"ok": True, **meta()})

    if path == "/api/messages" and method == "GET":
        return list_messages()

    if path == "/api/messages" and method == "POST":
        return create_message(event)

    return json_response(404, {"error": "Route not found", "meta": meta()})


def handler(event, context):
    try:
        if isinstance(event, str):
            text_event = event.strip()
            if text_event == "migrate" or ("maintenanceAction" in text_event and "migrate" in text_event):
                create_schema()
                return {"ok": True, "table": TABLE_NAME, **meta()}
            event = json.loads(text_event) if text_event else {}

        if event.get("maintenanceAction") == "migrate":
            create_schema()
            return {"ok": True, "table": TABLE_NAME, **meta()}

        return route_http(event)
    except Exception as error:
        return json_response(500, {"error": str(error), "meta": meta()})
