"""
# `versions`

Helper extension to manage the supported versions types.
"""

load("//version:semver.bzl", "semver")

VERSIONS = struct(
    SEMVER = "semver",
)

_VERSIONS = struct(
    semver = semver,
)

def _get_version_class(name, _fail = fail):
    version_class = getattr(_VERSIONS, name, None)

    if version_class == None:
        return _fail("Unsupported version class: %s" % name)

    return version_class

versions = struct(
    VERSIONS = VERSIONS,
    get_version_class = _get_version_class,
)
