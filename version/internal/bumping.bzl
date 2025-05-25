"""
# version bumping "trait"
"""

def _next_major(self):
    """
    Bumps major version.

    If self is a pre-major version, bump up to the same major version.
    Otherwise increment major.

    Examples:
        1.0.0-5 bumps to 1.0.0
        1.1.0-5 bumps to 2.0.0
        1.0.1-5 bumps to 2.0.0
        1.1.0 bumps to 2.0.0
    """
    if (
        self.prerelease and
        self.minor == 0 and
        (not self.has("patch") or self.patch == 0)
    ):
        new_major = self.major
    else:
        new_major = self.major + 1

    kwargs = dict(
        major = new_major,
        minor = 0,
        partial = self._partial,
    )

    if self.has("patch"):
        kwargs["patch"] = 0

    return self._new(**kwargs)

def _next_minor(self):
    """
    Bumps minor version.

    If this is a pre-minor version, bump up to the same minor version.
    Otherwise increment minor.

    Examples:
        1.2.0-5 bumps to 1.2.0
        1.2.1 bumps to 1.3.0
    """
    if (
        self.prerelease and
        (not self.has("patch") or self.patch == 0)
    ):
        new_minor = self.minor or 0
    else:
        new_minor = self.minor + 1

    kwargs = dict(
        major = self.major,
        minor = new_minor,
        partial = self._partial,
    )

    if self.has("patch"):
        kwargs["patch"] = 0

    return self._new(**kwargs)

def _next_patch(self):
    """
    Bumps patch version.

    If this is not a pre-release version, it will increment the patch.
    If it is a pre-release it will bump up to the same patch version.

    Examples:
        1.2.0-5 patches to 1.2.0
        1.2.0 patches to 1.2.1
    """
    if self.prerelease:
        new_patch = self.patch
    else:
        new_patch = self.patch + 1

    return self._new(
        major = self.major,
        minor = self.minor,
        patch = new_patch,
        partial = self._partial,
    )

_BUMP_LEVELS = dict(
    major = _next_major,
    minor = _next_minor,
    patch = _next_patch,
)

def _bump(self, level, _fail = fail):
    """
    Returns a new version, bumped at the selected level.
    """
    if level not in _BUMP_LEVELS or not self.has(level):
        return _fail("Invalid bump level `%s`." % level)

    return _BUMP_LEVELS[level](self)

def _new(self_dict):
    self = struct(**self_dict)

    self_dict["bump"] = \
        lambda level, _fail = fail: _bump(self, level, _fail)

    return self_dict

bumping = struct(
    new = _new,
)
