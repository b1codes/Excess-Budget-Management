"""backend/openapi.json is the API contract the Flutter client is tested
against (frontend/test/contract/). These keep it honest:

* the committed snapshot is exactly what the API serves, so an API change
  can't land without the snapshot (and so the client's contract tests) seeing it;
* every operation documents a typed success response, so the client side has
  something to check against.
"""

import json

from django.core.management import CommandError, call_command
import pytest

from apps.common import openapi


def test_snapshot_matches_the_served_schema():
    assert openapi.SNAPSHOT_PATH.read_text() == openapi.render(), (
        "backend/openapi.json is stale. Run `make openapi` (or `uv run python manage.py "
        "export_openapi` in backend/), review the diff, and update the Flutter client "
        "if the contract tests in frontend/test/contract/ now fail."
    )


def test_every_operation_has_a_typed_success_response():
    schema = json.loads(openapi.render())
    untyped = []
    for path, ops in schema["paths"].items():
        for method, op in ops.items():
            for status, response in op["responses"].items():
                if status == "204":
                    continue
                if "schema" not in response.get("content", {}).get("application/json", {}):
                    untyped.append(f"{method.upper()} {path} -> {status}")
    assert untyped == [], "Give these operations a response= schema."


def test_export_command_check_mode(tmp_path, monkeypatch):
    snapshot = tmp_path / "openapi.json"
    monkeypatch.setattr("apps.common.management.commands.export_openapi.SNAPSHOT_PATH", snapshot)

    with pytest.raises(CommandError, match="stale"):
        call_command("export_openapi", "--check")

    call_command("export_openapi")
    assert snapshot.read_text() == openapi.render()
    call_command("export_openapi")  # already up to date: no rewrite
    call_command("export_openapi", "--check")

    snapshot.write_text("{}\n")
    with pytest.raises(CommandError, match="stale"):
        call_command("export_openapi", "--check")
