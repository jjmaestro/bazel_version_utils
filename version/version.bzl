"""
# `version`

Bazel extension to work with version schemes.

Supported version schemes:

* [semantic (`SemVer`)]: e.g. `1.0.2-rc.1+b20250115`.
* [Postgres (`PgVer`)]: e.g. `16.0`, `17rc1`.

[semantic (`SemVer`)]: semver.md
[Postgres (`PgVer`)]: pgver.md
"""

load(":pgver.bzl", "pgver")
load(":semver.bzl", "semver")

SCHEME = struct(
    PGVER = "pgver",
    SEMVER = "semver",
)

_SCHEME = struct(
    pgver = pgver,
    semver = semver,
)

def _new(scheme, _fail = fail):
    cls = getattr(_SCHEME, scheme, None)

    if cls == None:
        return _fail("Unsupported version scheme: %s" % scheme)

    return cls

version = struct(
    SCHEME = SCHEME,
    new = _new,
)
