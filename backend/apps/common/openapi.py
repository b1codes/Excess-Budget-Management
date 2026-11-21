"""The committed OpenAPI snapshot (backend/openapi.json).

It's the contract between this API and the Flutter client: the frontend's
contract tests validate fixtures, requests and parsers against it, and
apps/common/tests/test_openapi_snapshot.py fails when the served schema and the
snapshot differ, so every API change shows up in review as a diff to it.

Regenerate with `make openapi` (or `uv run python manage.py export_openapi`).
"""

import json
from pathlib import Path

from django.conf import settings

PATH_PREFIX = "/api/v1/"
SNAPSHOT_PATH = Path(settings.BASE_DIR) / "openapi.json"


def render() -> str:
    """The schema the API serves, as the exact text the snapshot should hold."""
    from config.api import api

    schema = api.get_openapi_schema(path_prefix=PATH_PREFIX)
    return json.dumps(schema, indent=2, ensure_ascii=False) + "\n"
