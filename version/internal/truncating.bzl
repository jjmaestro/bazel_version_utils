"""
# version truncating "trait"
"""

def _truncate_major(self):
    kwargs = dict(
        major = self.major,
        minor = None if self._partial else 0,
        partial = self._partial,
    )

    if self.has("patch"):
        kwargs["patch"] = None if self._partial else 0

    return self._new(**kwargs)

def _truncate_minor(self):
    kwargs = dict(
        major = self.major,
        minor = 0 if self.minor == None and self.prerelease != () else self.minor,
        partial = self._partial,
    )

    if self.has("patch"):
        kwargs["patch"] = None if self._partial else 0

    return self._new(**kwargs)

def _truncate_patch(self):
    return self._new(
        major = self.major,
        minor = self.minor,
        patch = self.patch,
        partial = self._partial,
    )

def _truncate_prerelease(self):
    kwargs = dict(
        major = self.major,
        minor = self.minor,
        prerelease = self.prerelease,
        partial = self._partial,
    )

    if self.has("patch"):
        kwargs["patch"] = self.patch

    return self._new(**kwargs)

def _truncate_build(self):
    return self

_TRUNCATE_LEVELS = dict(
    major = _truncate_major,
    minor = _truncate_minor,
    patch = _truncate_patch,
    prerelease = _truncate_prerelease,
    build = _truncate_build,
)

def _truncate(self, level, _fail = fail):
    """
    Returns a new version, truncated up to the selected level.
    """
    if level not in _TRUNCATE_LEVELS or not self.has(level):
        return _fail("Invalid truncation level `%s`." % level)

    return _TRUNCATE_LEVELS[level](self)

def _new(self_dict, default_level = "patch"):
    self = struct(**self_dict)

    self_dict["truncate"] = \
        lambda level = default_level, _fail = fail: _truncate(self, level, _fail)

    return self_dict

truncating = struct(
    new = _new,
)
