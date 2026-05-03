#!/usr/bin/env python3
import json
import os
import subprocess
import time
import urllib.request
from typing import Any

PROD_REF = 'bfaczcsrpfcbijoaeckb'
BETA_REF = 'ggkvcpgvxqaqzwxehlns'
PAGE_SIZE = 500
TABLES = [
    'fun_facts',
    'daily_seeds',
    'cell_properties',
    'profiles',
    'cell_progress',
    'item_instances',
    'v3_profiles',
    'v3_items',
    'v3_cell_visits',
    'claimed_species',
    'collected_species',
    'app_logs',
]
USER_ID_COLUMNS = {
    'profiles': ['id'],
    'v3_profiles': ['id'],
    'cell_properties': ['created_by'],
    'cell_progress': ['user_id'],
    'item_instances': ['user_id'],
    'v3_items': ['user_id'],
    'v3_cell_visits': ['user_id'],
    'claimed_species': ['claimed_by'],
    'collected_species': ['user_id'],
    'app_logs': ['user_id'],
}
BETA_DB_URL = os.environ['BETA_DB_URL']


def run(cmd: list[str]) -> str:
    return subprocess.check_output(cmd, text=True)


def get_key(ref: str, key_id: str) -> str:
    data = json.loads(run(['supabase', 'projects', 'api-keys', '--project-ref', ref, '--output', 'json']))
    for item in data:
        if item.get('id') == key_id:
            return item['api_key']
    raise RuntimeError(f'{key_id} not found for {ref}')


def get_rows(ref: str, path: str, headers: dict[str, str]) -> Any:
    req = urllib.request.Request(f'https://{ref}.supabase.co/{path}', headers=headers)
    with urllib.request.urlopen(req, timeout=120) as resp:
        return json.load(resp)


def get_total(table: str, headers: dict[str, str]) -> int:
    req = urllib.request.Request(
        f'https://{PROD_REF}.supabase.co/rest/v1/{table}?select=*',
        method='HEAD',
        headers={**headers, 'Prefer': 'count=exact'},
    )
    with urllib.request.urlopen(req, timeout=120) as resp:
        content_range = resp.headers.get('Content-Range') or resp.headers.get('content-range') or '*/0'
        return int(content_range.split('/')[-1])


def truncate_tables() -> None:
    joined = ', '.join(f'public.{t}' for t in TABLES)
    sql = f'truncate table {joined} restart identity cascade;\n'
    subprocess.run(['psql', BETA_DB_URL, '-v', 'ON_ERROR_STOP=1'], input=sql, text=True, check=True)


def insert_batch(table: str, rows: list[dict[str, Any]]) -> None:
    payload = json.dumps(rows)
    sql = f"insert into public.{table} overriding system value select * from jsonb_populate_recordset(null::public.{table}, $earthnova${payload}$earthnova$::jsonb);\n"
    subprocess.run(['psql', BETA_DB_URL, '-v', 'ON_ERROR_STOP=1'], input=sql, text=True, check=True, capture_output=True)


def main() -> int:
    prod_service = get_key(PROD_REF, 'service_role')
    prod_headers = {'apikey': prod_service, 'Authorization': f'Bearer {prod_service}'}
    beta_service = get_key(BETA_REF, 'service_role')
    beta_headers = {'apikey': beta_service, 'Authorization': f'Bearer {beta_service}'}

    prod_users = get_rows(PROD_REF, 'auth/v1/admin/users?page=1&per_page=200', prod_headers)['users']
    beta_users = get_rows(BETA_REF, 'auth/v1/admin/users?page=1&per_page=200', beta_headers)['users']
    beta_by_email = {u['email']: u['id'] for u in beta_users}
    user_map = {u['id']: beta_by_email[u['email']] for u in prod_users if u.get('email') in beta_by_email}

    truncate_tables()

    for table in TABLES:
        total = get_total(table, prod_headers)
        print(f'{table}: {total}')
        for offset in range(0, total, PAGE_SIZE):
            batch = get_rows(PROD_REF, f'rest/v1/{table}?select=*&offset={offset}&limit={PAGE_SIZE}', prod_headers)
            remapped = []
            for row in batch:
                new_row = dict(row)
                for col in USER_ID_COLUMNS.get(table, []):
                    if new_row.get(col) is not None:
                        new_row[col] = user_map[new_row[col]]
                remapped.append(new_row)
            try:
                insert_batch(table, remapped)
            except subprocess.CalledProcessError as exc:
                print(f'FAILED table={table} offset={offset}:')
                print(exc.stderr)
                raise
            print(f'  inserted {min(offset + PAGE_SIZE, total)}/{total}')
            time.sleep(0.02)
    print('done')
    return 0


if __name__ == '__main__':
    raise SystemExit(main())
