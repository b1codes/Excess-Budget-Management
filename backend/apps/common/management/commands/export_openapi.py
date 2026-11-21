from django.core.management.base import BaseCommand, CommandError

from apps.common.openapi import SNAPSHOT_PATH, render


class Command(BaseCommand):
    help = "Write the API's OpenAPI schema to backend/openapi.json (--check: only compare)."

    def add_arguments(self, parser):
        parser.add_argument(
            "--check",
            action="store_true",
            help="Exit non-zero if the snapshot is stale instead of rewriting it.",
        )

    def handle(self, *args, check=False, **options):
        current = render()
        existing = SNAPSHOT_PATH.read_text() if SNAPSHOT_PATH.exists() else None
        if check:
            if existing != current:
                raise CommandError(
                    f"{SNAPSHOT_PATH.name} is stale. Run `make openapi` and commit the result."
                )
            self.stdout.write(f"{SNAPSHOT_PATH.name} is up to date.")
            return
        if existing == current:
            self.stdout.write(f"{SNAPSHOT_PATH.name} already up to date.")
            return
        SNAPSHOT_PATH.write_text(current)
        self.stdout.write(f"Wrote {SNAPSHOT_PATH}.")
