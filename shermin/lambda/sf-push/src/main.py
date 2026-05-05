"""
Twenty CRM → Salesforce push Lambda (Phase 2a: connection-only).

Phase 2a scope: prove end-to-end SF connectivity by calling describe on Account
and Contact, returning field counts + record types. No write logic yet.

Auth path: invoke the existing shared `lambda-sf-auth-{env}` Lambda which holds
the JWT keys + integration user + token exchange logic. Same pattern as polling,
lender-webhooks, ecommerce. We never load the JWT secret directly.

Event shape (CLI test):
    {"action": "describe", "sobjects": ["Account", "Contact"]}

Future event shapes (Phase 2b+):
    {"action": "upsert", "sobject": "Account", "externalIdField": "...", "record": {...}}
    {"action": "logActivity", "type": "Call", "accountId": "...", ...}
"""

import json
import os
import urllib.error
import urllib.request

import boto3

SF_AUTH_FUNCTION_NAME = os.environ["SF_AUTH_FUNCTION_NAME"]
SF_API_VERSION = os.environ.get("SF_API_VERSION", "v60.0")
HTTP_TIMEOUT_SECONDS = int(os.environ.get("HTTP_TIMEOUT_SECONDS", "15"))

_lambda = boto3.client("lambda")


def _resp(code: int, body: dict) -> dict:
    return {
        "statusCode": code,
        "headers": {"Content-Type": "application/json"},
        "body": json.dumps(body),
    }


def _get_access_token() -> tuple[str, str]:
    """Invoke the shared auth Lambda; return (access_token, instance_url)."""
    response = _lambda.invoke(
        FunctionName=SF_AUTH_FUNCTION_NAME,
        InvocationType="RequestResponse",
        Payload=json.dumps({"queryStringParameters": {"mode": "access_token"}}),
    )
    if response.get("StatusCode") != 200:
        raise RuntimeError(
            f"Auth Lambda invoke failed with StatusCode={response.get('StatusCode')}"
        )
    payload = json.loads(response["Payload"].read())
    if payload.get("statusCode") != 200:
        raise RuntimeError(f"Auth Lambda returned error: {payload}")
    body = json.loads(payload["body"])
    return body["access_token"], body["instance_url"]


def _describe_sobject(sobject: str, access_token: str, instance_url: str) -> dict:
    """Call SF describe endpoint; return a compact summary."""
    url = f"{instance_url}/services/data/{SF_API_VERSION}/sobjects/{sobject}/describe"
    req = urllib.request.Request(
        url,
        headers={
            "Authorization": f"Bearer {access_token}",
            "Accept": "application/json",
        },
    )
    try:
        with urllib.request.urlopen(req, timeout=HTTP_TIMEOUT_SECONDS) as r:
            data = json.loads(r.read())
    except urllib.error.HTTPError as e:
        raise RuntimeError(
            f"SF describe {sobject} failed: HTTP {e.code} {e.read().decode()[:300]}"
        )

    fields = data.get("fields", [])
    record_types = data.get("recordTypeInfos", [])

    return {
        "name": data.get("name"),
        "label": data.get("label"),
        "labelPlural": data.get("labelPlural"),
        "createable": data.get("createable"),
        "updateable": data.get("updateable"),
        "fieldCount": len(fields),
        "customFieldCount": sum(1 for f in fields if f.get("custom")),
        "standardFieldCount": sum(1 for f in fields if not f.get("custom")),
        "recordTypes": [
            {
                "name": rt.get("name"),
                "developerName": rt.get("developerName"),
                "available": rt.get("available"),
                "defaultRecordTypeMapping": rt.get("defaultRecordTypeMapping"),
            }
            for rt in record_types
        ],
        "sampleFields": [
            {"name": f.get("name"), "type": f.get("type"), "custom": f.get("custom")}
            for f in fields[:15]
        ],
    }


def lambda_handler(event, context):
    action = (event or {}).get("action", "describe")

    try:
        if action == "describe":
            sobjects = event.get("sobjects") or ["Account", "Contact"]
            access_token, instance_url = _get_access_token()
            result = {
                sobj: _describe_sobject(sobj, access_token, instance_url)
                for sobj in sobjects
            }
            return _resp(200, {"action": action, "instance_url": instance_url, "result": result})

        return _resp(400, {"error": f"unsupported action: {action!r}"})

    except Exception as e:
        return _resp(500, {"error": str(e), "type": type(e).__name__})
