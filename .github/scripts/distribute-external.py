#!/usr/bin/env python3
"""Give the build this run uploaded to the public TestFlight group (owner 2026-11-13).

Why: testers join with one public link (https://testflight.apple.com/join/eN8Uh7Gg)
instead of App Store Connect team invitations, which send them through
Apple's developer-account form. An external group gets a build only when
someone adds it and submits it for Beta App Review; the internal groups
(«Owner», «Алфа») get builds on their own.

What it does, once the upload has finished processing (it waits up to 30
minutes): sets the build's «What to Test» from WHATS_NEW, adds the build to
the group named PUBLIC_GROUP, and submits it for Beta App Review. Apple
reviews the first build of a version; later builds of the same version
usually pass at once. A step that fails here does not touch the upload.

Signing: the same openssl-signed JWT as revoke-run-certificate.py, imported
from it, so no third-party package runs with the key.

Env: ASC_KEY_PATH, ASC_KEY_ID, ASC_ISSUER_ID, APP_ID, BUILD_NUMBER,
PUBLIC_GROUP (default «Публичен линк»), WHATS_NEW.
"""
from __future__ import annotations

import importlib.util
import json
import os
import sys
import time
import urllib.error
import urllib.parse
import urllib.request
from pathlib import Path

API = "https://api.appstoreconnect.apple.com/v1"

_spec = importlib.util.spec_from_file_location("revoke", Path(__file__).with_name("revoke-run-certificate.py"))
revoke = importlib.util.module_from_spec(_spec)
_spec.loader.exec_module(revoke)


def call(token: str, method: str, path: str, body: dict | None = None):
    req = urllib.request.Request(
        f"{API}/{path}", method=method,
        data=json.dumps(body).encode() if body is not None else None,
        headers={"Authorization": f"Bearer {token}", "Content-Type": "application/json"},
    )
    try:
        with urllib.request.urlopen(req, timeout=30) as resp:
            text = resp.read()
            return resp.status, (json.loads(text) if text else None)
    except urllib.error.HTTPError as e:
        text = e.read()
        return e.code, (json.loads(text) if text else None)


def problem(answer) -> str:
    errors = (answer or {}).get("errors") or []
    return errors[0].get("detail") or errors[0].get("title") or "" if errors else ""


def main() -> int:
    env = os.environ
    key, key_id, issuer = env["ASC_KEY_PATH"], env["ASC_KEY_ID"], env["ASC_ISSUER_ID"]
    app, number = env["APP_ID"], env["BUILD_NUMBER"]
    group_name = env.get("PUBLIC_GROUP") or "Публичен линк"
    # The merge's commit message, without its trailers (Co-Authored-By, …):
    # testers read what changed, not who wrote it.
    lines = [line for line in (env.get("WHATS_NEW") or "").splitlines()
             if not line.startswith(("Co-Authored-By:", "Claude-Session:", "Signed-off-by:"))]
    whats_new = "\n".join(lines).strip()[:4000]

    def token() -> str:  # a JWT lives 20 minutes; the wait is longer
        return revoke.jwt(key, key_id, issuer)

    query = urllib.parse.urlencode({"filter[app]": app, "filter[version]": number, "fields[builds]": "processingState"})
    build = None
    for _ in range(60):  # 30 minutes
        status, answer = call(token(), "GET", f"builds?{query}")
        rows = (answer or {}).get("data") or []
        if rows and rows[0]["attributes"]["processingState"] == "VALID":
            build = rows[0]["id"]
            break
        if rows and rows[0]["attributes"]["processingState"] in ("FAILED", "INVALID"):
            print(f"build {number} did not process: {rows[0]['attributes']['processingState']}")
            return 1
        time.sleep(30)
    if not build:
        print(f"build {number} was not ready after 30 minutes; add it to «{group_name}» by hand")
        return 1

    status, answer = call(token(), "GET", f"apps/{app}/betaGroups?fields[betaGroups]=name,isInternalGroup&limit=50")
    group = next((g["id"] for g in (answer or {}).get("data", [])
                  if g["attributes"]["name"] == group_name and not g["attributes"]["isInternalGroup"]), None)
    if not group:
        print(f"no external group «{group_name}»")
        return 1

    if whats_new:
        status, answer = call(token(), "POST", "betaBuildLocalizations", {"data": {
            "type": "betaBuildLocalizations", "attributes": {"locale": "en-US", "whatsNew": whats_new},
            "relationships": {"build": {"data": {"type": "builds", "id": build}}}}})
        if status >= 300:
            print(f"«What to Test» not set ({status}): {problem(answer)}")

    status, answer = call(token(), "POST", f"betaGroups/{group}/relationships/builds",
                          {"data": [{"type": "builds", "id": build}]})
    if status >= 300:
        print(f"could not add build {number} to «{group_name}» ({status}): {problem(answer)}")
        return 1

    status, answer = call(token(), "POST", "betaAppReviewSubmissions", {"data": {
        "type": "betaAppReviewSubmissions",
        "relationships": {"build": {"data": {"type": "builds", "id": build}}}}})
    # A build of a version already approved may need no submission: Apple says so with a 409.
    if status >= 300 and status != 409:
        print(f"could not submit build {number} for review ({status}): {problem(answer)}")
        return 1
    print(f"build {number} is in «{group_name}» and submitted for Beta App Review")
    return 0


if __name__ == "__main__":
    sys.exit(main())
