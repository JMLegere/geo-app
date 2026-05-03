#!/usr/bin/env python3
"""Clone EarthNova production data into the beta Supabase project.

Required:
  BETA_DB_URL=postgresql://... python scripts/clone_prod_to_beta.py

The script is intentionally beta-only. It reads production through the Supabase
REST/Auth admin APIs, creates any missing beta auth users with the same derived
phone password scheme, truncates the beta public tables below, and reloads data
through direct SQL so schema-cache lag and identity columns do not break the run.
"""

from __future__ import annotations

import hashlib
import json
import math
import os
import subprocess
import sys
import time
import urllib.error
import urllib.request
from typing import Any

PROD_REF = "bfaczcsrpfcbijoaeckb"
BETA_REF = "ggkvcpgvxqaqzwxehlns"
PAGE_SIZE = 500
USER_PAGE_SIZE = 200
TABLES = [
    "countries",
    "states",
    "cities",
    "districts",
    "location_nodes",
    "species",
    "fun_facts",
    "daily_seeds",
    "cell_properties",
    "profiles",
    "cell_progress",
    "item_instances",
    "v3_profiles",
    "v3_items",
    "v3_cell_visits",
    "claimed_species",
    "collected_species",
    "app_logs",
]
USER_ID_COLUMNS = {
    "profiles": ["id"],
    "v3_profiles": ["id"],
    "cell_properties": ["created_by"],
    "cell_progress": ["user_id"],
    "item_instances": ["user_id"],
    "v3_items": ["user_id"],
    "v3_cell_visits": ["user_id"],
    "claimed_species": ["claimed_by"],
    "collected_species": ["user_id"],
    "app_logs": ["user_id"],
}
BETA_DB_URL = os.environ.get("BETA_DB_URL")
if not BETA_DB_URL:
    raise SystemExit("BETA_DB_URL is required")


def run(cmd: list[str]) -> str:
    return subprocess.check_output(cmd, text=True)


def get_service_role(ref: str) -> str:
    data = json.loads(run(["supabase", "projects", "api-keys", "--project-ref", ref, "--output", "json"]))
    for item in data:
        if item.get("id") == "service_role":
            return item["api_key"]
    raise RuntimeError(f"service_role key not found for {ref}")


def request_json(method: str, url: str, headers: dict[str, str], body: Any | None = None) -> Any:
    data = json.dumps(body).encode() if body is not None else None
    req = urllib.request.Request(url, data=data, method=method, headers=headers)
    with urllib.request.urlopen(req, timeout=120) as resp:
        raw = resp.read().decode()
        return json.loads(raw) if raw else None


def request_headers(method: str, url: str, headers: dict[str, str]) -> dict[str, str]:
    req = urllib.request.Request(url, method=method, headers=headers)
    with urllib.request.urlopen(req, timeout=120) as resp:
        return dict(resp.headers.items())


def rest_url(ref: str, table: str, query: str = "") -> str:
    return f"https://{ref}.supabase.co/rest/v1/{table}{query}"


def auth_url(ref: str, path: str, query: str = "") -> str:
    return f"https://{ref}.supabase.co/auth/v1/{path}{query}"


def fetch_total(table: str, key: str) -> int:
    headers = request_headers(
        "HEAD",
        rest_url(PROD_REF, table, "?select=*"),
        {"apikey": key, "Authorization": f"Bearer {key}", "Prefer": "count=exact"},
    )
    content_range = headers.get("Content-Range") or headers.get("content-range") or "*/0"
    return int(content_range.split("/")[-1])


def fetch_rows(table: str, offset: int, limit: int, key: str) -> list[dict[str, Any]]:
    return request_json(
        "GET",
        rest_url(PROD_REF, table, f"?select=*&offset={offset}&limit={limit}"),
        {"apikey": key, "Authorization": f"Bearer {key}"},
    )


def insert_rows(table: str, rows: list[dict[str, Any]]) -> None:
    if not rows:
        return
    payload = json.dumps(rows)
    sql = (
        f"insert into public.{table} overriding system value "
        f"select * from jsonb_populate_recordset(null::public.{table}, "
        f"$earthnova${payload}$earthnova$::jsonb);\n"
    )
    subprocess.run(
        ["psql", BETA_DB_URL, "-v", "ON_ERROR_STOP=1"],
        input=sql,
        text=True,
        check=True,
        capture_output=True,
    )


def truncate_tables() -> None:
    joined = ", ".join(f"public.{table}" for table in TABLES)
    sql = f"truncate table {joined} restart identity cascade;\n"
    subprocess.run(["psql", BETA_DB_URL, "-v", "ON_ERROR_STOP=1"], input=sql, text=True, check=True)


def derive_password(phone: str) -> str:
    return hashlib.sha256(f"{phone}:earthnova-beta-2026".encode()).hexdigest()


def fetch_users(ref: str, key: str) -> list[dict[str, Any]]:
    users: list[dict[str, Any]] = []
    page = 1
    while True:
        batch = request_json(
            "GET",
            auth_url(ref, f"admin/users?page={page}&per_page={USER_PAGE_SIZE}"),
            {"apikey": key, "Authorization": f"Bearer {key}"},
        )
        rows = batch.get("users", [])
        users.extend(rows)
        if len(rows) < USER_PAGE_SIZE:
            return users
        page += 1


def phone_for_user(user: dict[str, Any]) -> str:
    phone = user.get("user_metadata", {}).get("phone_number")
    if phone:
        return phone
    local = (user.get("email") or "").split("@", 1)[0]
    digits = "".join(ch for ch in local if ch.isdigit())
    return f"+{digits}" if digits else "+10000000000"


def create_beta_user(user: dict[str, Any], beta_key: str) -> str:
    phone = phone_for_user(user)
    payload = {
        "email": user.get("email"),
        "password": derive_password(phone),
        "email_confirm": True,
        "user_metadata": user.get("user_metadata") or {"phone_number": phone},
        "app_metadata": user.get("app_metadata") or {"provider": "email", "providers": ["email"]},
    }
    created = request_json(
        "POST",
        auth_url(BETA_REF, "admin/users"),
        {
            "apikey": beta_key,
            "Authorization": f"Bearer {beta_key}",
            "Content-Type": "application/json",
        },
        payload,
    )
    return created["id"]


def build_user_map(prod_users: list[dict[str, Any]], beta_key: str) -> dict[str, str]:
    beta_users = fetch_users(BETA_REF, beta_key)
    beta_by_email = {user.get("email"): user["id"] for user in beta_users if user.get("email")}
    user_map: dict[str, str] = {}
    for idx, user in enumerate(prod_users, start=1):
        email = user.get("email")
        if email in beta_by_email:
            new_id = beta_by_email[email]
        else:
            new_id = create_beta_user(user, beta_key)
            beta_by_email[email] = new_id
        user_map[user["id"]] = new_id
        if idx % 10 == 0 or idx == len(prod_users):
            print(f"mapped {idx}/{len(prod_users)} beta auth users")
    return user_map


def remap_rows(table: str, rows: list[dict[str, Any]], user_map: dict[str, str]) -> list[dict[str, Any]]:
    columns = USER_ID_COLUMNS.get(table, [])
    remapped: list[dict[str, Any]] = []
    for row in rows:
        new_row = dict(row)
        for column in columns:
            value = new_row.get(column)
            if value is None:
                continue
            if value not in user_map:
                raise RuntimeError(f"missing user mapping for {table}.{column}={value}")
            new_row[column] = user_map[value]
        remapped.append(new_row)
    return remapped


def main() -> int:
    prod_key = get_service_role(PROD_REF)
    beta_key = get_service_role(BETA_REF)

    print("fetching production auth users...")
    prod_users = fetch_users(PROD_REF, prod_key)
    print(f"found {len(prod_users)} auth users")
    user_map = build_user_map(prod_users, beta_key)

    print("truncating beta public tables...")
    truncate_tables()

    for table in TABLES:
        total = fetch_total(table, prod_key)
        if total == 0:
            print(f"{table}: 0 rows, skipped")
            continue
        pages = math.ceil(total / PAGE_SIZE)
        print(f"{table}: cloning {total} rows across {pages} pages")
        for page_index in range(pages):
            offset = page_index * PAGE_SIZE
            rows = fetch_rows(table, offset, PAGE_SIZE, prod_key)
            rows = remap_rows(table, rows, user_map)
            insert_rows(table, rows)
            if (page_index + 1) % 10 == 0 or page_index + 1 == pages:
                print(f"  {table}: page {page_index + 1}/{pages}")
            time.sleep(0.02)

    print("beta seed complete")
    return 0


if __name__ == "__main__":
    try:
        raise SystemExit(main())
    except urllib.error.HTTPError as exc:
        body = exc.read().decode()
        print(f"HTTP {exc.code}: {body}", file=sys.stderr)
        raise
