from config.settings import _parse_db


def test_parse_db_url():
    assert _parse_db("postgres://app:secret@db.internal:6543/excess") == {
        "ENGINE": "django.db.backends.postgresql",
        "NAME": "excess",
        "USER": "app",
        "PASSWORD": "secret",
        "HOST": "db.internal",
        "PORT": "6543",
    }


def test_parse_db_url_defaults_port():
    assert _parse_db("postgres://app:secret@db/excess")["PORT"] == "5432"


def test_parse_db_url_decodes_credentials():
    # Regression: percent-encoded credentials were passed to Postgres undecoded.
    parsed = _parse_db("postgres://app%40corp:p%40ss%3Aw%2Frd@db/excess")
    assert parsed["USER"] == "app@corp"
    assert parsed["PASSWORD"] == "p@ss:w/rd"


def test_parse_db_url_without_credentials():
    parsed = _parse_db("postgres://db/excess")
    assert parsed["USER"] is None and parsed["PASSWORD"] is None
