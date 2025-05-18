"""
# `semver`

Bazel extension to work with [semantic versions] (e.g.
`1.0.2-alpha+build.2025-01-15`).

A `SemVer` `struct` is a `struct` ("object") representation of a
SemVer-compliant version.

It can be created from a semantic version string:

```starlark
load("@version_utils//version:semver.bzl", "semver")

version = semver.parse("1.0.2-alpha+build.2025-01-15")

print(version.major, version.minor, version.patch)
# 1 0 2

print(version.prerelease)
# ("alpha",)

print(version.build)
# ("build", "2025-01-15")

print(version.to_str())
# 1.0.2-alpha+build.2025-01-15
```

If the provided version string is not a valid semantic version, it will `fail`:
```starlark
version = semver.parse("0.1.2.3")
# Error in fail: Invalid semantic version: 0.1.2.3

version = semver.parse("0.1")
# Error in fail: Invalid semantic version minor/patch value: None
```

It can also be created by specifying its named fields:

```starlark
version = semver.new(major = 1, minor = 0, patch = 2)

print(version.major, version.minor, version.patch)
# 1 0 2

version = semver.new(major = 1, minor = 0)
# Error in fail: Invalid semantic version minor/patch value: None
```

If provided, `prerelease` and `build` must be `tuple`s of `string`s:

```starlark
version = semver.new(major = 1, minor = 0, patch = 2, prerelease = ("alpha", "2"))

print(version.prerelease)
# ("alpha", 2)

version = semver.new(major = 1, minor = 0, patch = 2, build = ("b", "2154"))

print(version.build)
# ("b", 2154)
```

## Comparing

To compare versions, use the comparison methods `lt`, `le`, `gt`, `ge`, `eq`
and `ne`:

```starlark
v1 = semver.parse("0.1.1")
v2 = semver.parse("0.1.2")
v3 = semver.parse("0.1.1-alpha.1")

res = v1.lt(v2)
print(res)
# True

res = v1.gt(v3)
print(res)
# True

res = v1.le(v3)
print(res)
# False
```

Also, there's a `cmp` method that compares two versions, `v1` and `v2`, and
returns an integer indicating their relative order:
* `-1` if `v1 < v2`
* `0` if `v1 == v2`
* `1` if `v1 > v2`

## Incrementing ("bumping")

Versions can be incremented ("bumped") in any of their version fields:

```starlark
version = semver.parse("1.0.0+build")

bumped = version.bump("patch")
print(bumped.to_str())
# 1.0.1

bumped = version.bump("minor")
print(bumped.to_str())
# 1.1.0

bumped = version.bump("major")
print(bumped.to_str())
# 2.0.0
```

## Truncating

Versions can be truncated up to any of their version fields:

```starlark
version = semver.parse("1.2.3-pre.1+build.1")

truncated = version.truncate("build")
print(truncated.to_str())
# 1.2.3-pre.1+build.1

truncated = version.truncate("prerelease")
print(truncated.to_str())
# 1.2.3-pre.1

truncated = version.truncate("patch")
print(truncated.to_str())
# 1.2.3

truncated = version.truncate("minor")
print(truncated.to_str())
# 1.1.0

truncated = version.truncate("major")
print(truncated.to_str())
# 1.0.0
```

[semantic versions]: https://semver.org
"""

load("//version/internal:bumping.bzl", "bumping")
load("//version/internal:comparing.bzl", "comparing")
load("//version/internal:truncating.bzl", "truncating")
load("//version/internal:utils.bzl", "utils")

__CLASS__ = "SemVer"

def _parse_identifiers(identifiers):
    if type(identifiers) == "string":
        parsed = tuple([p for p in identifiers.split(".")])
    elif identifiers == None:
        parsed = ()
    elif type(identifiers) != "tuple":
        parsed = tuple(identifiers)
    elif type(identifiers) == "tuple":
        parsed = identifiers
    else:
        fail("Invalid identifiers type: %s" % type(identifiers))

    return parsed

def _parse_re(version, _fail = fail):
    r"""
    Parses a semantic version string into a tuple.

    This method is a close equivalent to parsing a semver version string with a
    regex such as:

    ```regex
    ^
    (?P<major>\d+)(?:\.(?P<minor>\d+)(?:\.(?P<patch>\d+))?)?
    (?:-(?P<prerelease>[0-9a-zA-Z.-]*))?
    (?:\+(?P<build>[0-9a-zA-Z.-]*))?
    $
    ```

    Args:
        version (string): A semantic version string (e.g. `"1.5.2-rc.1-b20"`).
        _fail (function): **[TESTING]** Mock of the `fail()` function.

    Returns:
        A tuple of strings with the parts that potentially make a semantic
        version.
    """
    if type(version) != "string":
        return _fail("Invalid version string: %s" % str(version))

    if version == "":
        return _fail("Empty version string")

    # split and parse build metadata
    parts = version.split("+", 1)
    version_part = parts[0]
    build = parts[1] if len(parts) > 1 else None
    build = _parse_identifiers(build)

    # split and parse pre-release
    parts = version_part.split("-", 1)
    core_version = parts[0]
    prerelease = parts[1] if len(parts) > 1 else None
    prerelease = _parse_identifiers(prerelease)

    # split core parts (major, minor, patch)
    core_parts = core_version.split(".")

    if len(core_parts) > 3:
        return _fail("Invalid semantic version: %s" % version)
    elif len(core_parts) < 3:
        core_parts += [None] * (3 - len(core_parts))

    major, minor, patch = core_parts

    return major, minor, patch, prerelease, build

def _is_valid_normal_version_number(value, partial = False):
    """
    Checks if the value is a valid SemVer normal version number.

    The SemVer spec says:

    > A normal version number MUST take the form X.Y.Z where X, Y, and Z are
    > non-negative integers, and MUST NOT contain leading zeroes. X is the
    > major version, Y is the minor version, and Z is the patch version.

    This method also allows `None` if `partial` is True (for incomplete
    versions like "1.2").

    Args:
        value (string): The value to validate.
        partial (bool): Whether to accept `None` as a valid normal version
            number.

    Returns:
        `True if the value is a valid normal version number, `False` otherwise.
    """
    return (
        (value == None and partial) or
        (utils.is_uint(value) and not utils.has_leading_zero(value))
    )

def _is_valid_identifier(
        value,
        allow_leading_zeroes = False,
        allow_empty = False):
    """
    Checks if the value is a valid SemVer prerelease or build identifier.

    The SemVer spec says:

    > Pre-release:
    >   - Identifiers MUST comprise only ASCII alphanumerics and hyphens
    >     [0-9A-Za-z-].
    >   - Identifiers MUST NOT be empty.
    >   - Numeric identifiers MUST NOT include leading zeroes.
    >
    > Build metadata:
    >   - Identifiers MUST comprise only ASCII alphanumerics and hyphens
    >     [0-9A-Za-z-].
    >   - Identifiers MUST NOT be empty.

    Args:
        value (string): The value to validate.
        allow_leading_zeroes (bool): Whether to allow leading zeroes in a
            numeric identifier.
        allow_empty (bool): Whether to allow an empty identifier. Although this
            is not strictly valid in a SemVer version, it is needed when
            parsing and validating SemVer versions that are part of a version
            specification.

    Returns:
        `True if the value is a valid prerelease or build identifier, `False`
        otherwise.
    """
    if value == "":
        return allow_empty

    def valid(s):
        return s == "" or (
            # NOTE: isalnum checks for Unicode but it should be only ASCII
            s.isalnum() and
            not utils.has_leading_zero(s, allow_leading_zeroes)
        )

    return all([valid(s) for s in str(value).split("-")])

def _is_valid_prerelease_identifier(value, allow_empty = False):
    return _is_valid_identifier(
        value,
        allow_leading_zeroes = False,
        allow_empty = allow_empty,
    )

def _is_valid_build_identifier(value, allow_empty = False):
    return _is_valid_identifier(
        value,
        allow_leading_zeroes = True,
        allow_empty = allow_empty,
    )

def _validate(
        major,
        minor,
        patch,
        prerelease,
        build,
        partial = False,
        allow_empty = False,
        _fail = fail):
    if not _is_valid_normal_version_number(major):
        return _fail("Invalid semantic version major value: %r" % major)

    for value in (minor, patch):
        if not _is_valid_normal_version_number(value, partial):
            msg = "Invalid semantic version minor/patch value: %r"
            return _fail(msg % value)

    validate_identifiers = (
        (prerelease, _is_valid_prerelease_identifier),
        (build, _is_valid_build_identifier),
    )

    for identifiers, validate in validate_identifiers:
        msg = "Invalid semantic version prerelease/build: %s"

        if identifiers == None and not partial:
            return _fail(msg % str(identifiers))

        for value in identifiers:
            if not validate(value, allow_empty = allow_empty):
                return _fail(msg % str(identifiers))

    major = utils.coerce(major, partial = False)
    minor = utils.coerce(minor, partial = partial)
    patch = utils.coerce(patch, partial = partial)

    partial = any([f == None for f in (major, minor, patch)])

    prerelease = tuple([int(p) if utils.is_uint(p) else p for p in prerelease])
    build = tuple([int(p) if utils.is_uint(p) else p for p in build])

    return major, minor, patch, prerelease, build, partial

def _to_str(self):
    """
    Converts the `SemVer` `struct` into a semantic version string.

    Args:
        self (`SemVer`): A `SemVer` `struct`.

    Returns:
        A string representation of the version, following the SemVer format:

        `major[.minor[.patch]][-prerelease][+build]`

        Note that, to support partial versions, the `minor` and `patch`
        components are included only if not `None`.
    """
    version = "%d" % self.major

    for value in (self.minor, self.patch):
        if value != None:
            version += ".%d" % value

    for parts, sep in ((self.prerelease, "-"), (self.build, "+")):
        if parts != () and parts:
            version += "%s%s" % (sep, ".".join([str(p) for p in parts]))

    return version

def _new(
        major,
        minor = None,
        patch = None,
        prerelease = (),
        build = (),
        partial = False,
        _fail = fail):
    """
    Constructs a `SemVer` `struct`.

    Args:
        major (string): SemVer major string (e.g. `1`).
        minor (string): SemVer minor string (e.g. `2`).
        patch (string): SemVer patch string (e.g. `3`).
        prerelease (tuple[string]): SemVer prerelease (e.g. `("beta", "1")`).
        build (tuple[string]): SemVer build metadata (e.g. `("build", "001")`).
        partial (bool): Whether to accept partial versions (e.g. `1` or `1.0`
            instead of `1.0.0`).
        _fail (function): **[TESTING]** Mock of the fail() function

    Returns:
        A `SemVer` `struct`.
    """
    fields = _validate(
        major,
        minor,
        patch,
        prerelease,
        build,
        partial = partial,
        _fail = _fail,
    )

    if _fail != fail and type(fields) == "string":
        # testing: _fail returned an error string
        return fields

    major, minor, patch, prerelease, build, partial = fields
    fields = fields[:-1]

    __cmp_key__ = comparing.make_precedence_key(fields[:-1])  # w/o build
    __sort_key__ = comparing.make_precedence_key(fields)  # with build

    self_dict = dict(
        __class__ = __CLASS__,
        _partial = partial,
        __is__ = lambda other: _is(other),
        __cmp_key__ = __cmp_key__,
        __sort_key__ = __sort_key__,
        _new = _new,
        major = major,
        minor = minor,
        patch = patch,
        prerelease = prerelease,
        build = build,
    )

    self = struct(**self_dict)

    self_dict |= dict(
        to_str = lambda: _to_str(self),
    )

    self_dict |= comparing.new(self_dict)
    self_dict |= bumping.new(self_dict)
    self_dict |= truncating.new(self_dict)

    return struct(**self_dict)

def _parse(
        version,
        partial = False,
        _fail = fail):
    """
    Parses a version string into a `SemVer` `struct`.

    Args:
        version (string): a semantic version string (e.g. `"1.5.2-rc.1-b20"`)
        partial (bool): whether to accept partial versions (e.g. `"1"` or
            `"1.0"` instead of `"1.0.0"`)
        _fail (function): **[TESTING]** mock of the fail() function

    Returns:
        A `SemVer` `struct`.
    """
    if _is(version):
        return version

    res = _parse_re(version, _fail = _fail)

    if _fail != fail and type(res) == "string":
        # testing: _fail returned an error string
        return res

    return _new(
        partial = partial,
        _fail = _fail,
        *res
    )

def _compare(v1, v2, _parse = _parse):
    """
    Compares two semantic versions.

    Args:
        v1 (string): A semantic version string (e.g. `"1.5.2-rc.1-b20"`) or a
            `SemVer` `struct`.
        v2 (string): Another semantic version string or a `SemVer` `struct`.
        _parse: **[INTERNAL]** Parser method used to convert strings to SemVer
            structs.

    Returns:
        An integer indicating the relative order of `v1` vs `v2`:
        - `-1` if `v1 < v2`
        - `0` if `v1 == v2`
        - `1` if `v1 > v2`
    """
    sv1, sv2 = [_parse(version) for version in (v1, v2)]
    return sv1.cmp(sv2)

def _sorted(versions, reverse = False):
    """
    Sorts a list of semantic version strings.

    Args:
        versions (list[string]): A list of semantic version strings (e.g.
            `"1.5.2-rc.1-b20"`) or `SemVer` `struct`s.
        reverse (bool): If `True`, sorts in descending order. Defaults to
            `False` (ascending).

    Returns:
        A new list of `SemVer` `struct`s, sorted according to semantic version
        precedence.
    """
    return comparing.sorted(versions, reverse = reverse)

def _is(value):
    """
    Checks whether the given value is a `SemVer` `struct`.

    Args:
        value: The value to check.

    Returns:
        `True` if the value is a `SemVer` struct, `False` otherwise.
    """
    return utils.is_(value, __CLASS__)

semver = struct(
    new = _new,
    parse = _parse,
    compare = _compare,
    sorted = _sorted,
    is_ = _is,
    __internal__ = struct(
        _parse_re = _parse_re,
        _validate = _validate,
    ),
    __test__ = struct(
        _is_valid_normal_version_number = _is_valid_normal_version_number,
        _is_valid_prerelease_identifier = _is_valid_prerelease_identifier,
        _is_valid_build_identifier = _is_valid_build_identifier,
    ),
)
