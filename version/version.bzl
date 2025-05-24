"""
# `version`

Bazel extension to work with version schemes.

Supported version schemes:

* [semantic (`SemVer`)]: e.g. `1.0.2-rc.1+b20250115`.

[semantic (`SemVer`)]: semver.md
"""

load(":semver.bzl", "semver")

SCHEME = struct(
    SEMVER = "semver",
)

_SCHEME = struct(
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
