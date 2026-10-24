import json
import logging

from rag_query.__main__ import get_log_level, rag_query

logger = logging.getLogger(__name__)

logging.getLogger().setLevel(get_log_level())


def parse_event(event: dict) -> dict:
    # API Gateway / Function URL events carry the request as a JSON string in "body";
    # direct invocations pass the parameters at the top level.
    body = event.get("body")
    if body is None:
        return event
    if isinstance(body, str):
        return json.loads(body) if body.strip() else {}
    return body


def build_response(status_code: int, body: dict) -> dict:
    return {
        "statusCode": status_code,
        "headers": {"Content-Type": "application/json"},
        "body": json.dumps(body),
    }


def handler(event: dict, context) -> dict:
    try:
        params = parse_event(event or {})
    except json.JSONDecodeError:
        logger.warning("Request body is not valid JSON.")
        return build_response(400, {"error": "Request body must be valid JSON."})

    query_text = params.get("query_text")
    if query_text is None or not str(query_text).strip():
        return build_response(400, {"error": "'query_text' is required."})

    try:
        llm_response = rag_query(query_text, params.get("brand"), params.get("family"))
    except Exception:
        logger.exception("RAG query failed.")
        return build_response(500, {"error": "Internal error while processing the query."})

    return build_response(200, {"response": llm_response})
