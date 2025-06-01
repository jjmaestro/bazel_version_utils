"""
# `pgver`

Bazel extension to work with [Postgres versions] (e.g. `16.2` or `17beta1`).

A `PgVer` `struct` is a `struct` ("object") representation of a
Postgres-compliant version.

> [!NOTE]
> Internally, `PgVer` `struct`s are converted to `SemVer`-compatible `struct`s
> to ensure compatibility with version requirement `Spec`s that operate on
> semantic versions.

It can be created from a Postgres version string:

```starlark
load("@version_utils//version:pgver.bzl", "pgver")

version = pgver.parse("16.2")

print(version.major, version.minor, version.prerelease)
# 16 2 ()

print(version.to_str())
# 16.2

version = pgver.parse("17beta1")

print(version.major, version.minor, version.prerelease)
# 17 0 ("beta", 1)

print(version.to_str())
# 17beta1
```

If the provided version string is not a valid Postgres version, it will `fail`:
```starlark
version = pgver.parse("16.2beta1")
# Error in fail: Invalid Postgres version major value: "16.2"
```

It can also be created by specifying its named fields:

```starlark
version = pgver.new(major = 16, minor = 2)

print(version.major, version.minor, version.prerelease)
# 16 2 ()

version = pgver.new(major = 16)
# Error in fail: Invalid Postgres version minor value: None
```

If provided, `prerelease` must be a `tuple`s of `string`s:

```starlark
version = pgver.new(major = 17, prerelease = ("beta", "1"))

print(version.major, version.minor, version.prerelease)
# 17 0 ("beta", 1)
```

## Comparing

To compare versions, use the comparison methods `lt`, `le`, `gt`, `ge`, `eq`
and `ne`:

```starlark
v1 = pgver.parse("16.1")
v2 = pgver.parse("16.2")
v3 = pgver.parse("16rc1")

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
version = pgver.parse("16.0")

bumped = version.bump("minor")
print(bumped.to_str())
# 16.1

bumped = version.bump("major")
print(bumped.to_str())
# 17.0
```

## Truncating

Versions can be truncated up to any of their version fields:

```starlark
version = pgver.parse("16.2")

truncated = version.truncate("prerelease")
print(truncated.to_str())
# 16.2

truncated = version.truncate("minor")
print(truncated.to_str())
# 16.2

truncated = version.truncate("major")
print(truncated.to_str())
# 16.0


version = pgver.parse("17beta1")

truncated = version.truncate("prerelease")
print(truncated.to_str())
# 17beta1

truncated = version.truncate("minor")
print(truncated.to_str())
# 17.0

truncated = version.truncate("major")
print(truncated.to_str())
# 17.0
```

[Postgres versions]: https://www.postgresql.org/support/versioning/
"""

load("//version:semver.bzl", SemVer = "semver")
load("//version/internal:bumping.bzl", "bumping")
load("//version/internal:comparing.bzl", "comparing")
load("//version/internal:truncating.bzl", "truncating")
load("//version/internal:utils.bzl", "utils")

__CLASS__ = "PgVer"

_FIELDS = ("major", "minor", "prerelease", "build")

def _parse_re(version, strict = False, _fail = fail):
    r"""
    Parses a Postgres version string into a tuple.

    This method is a close equivalent to parsing a Postgres version string with
    a regex such as:

    ```regex
    ^
    (?P<major>\d+)
    ((?:\.(?P<minor>\d+))? | (?P<prerelease>(alpha|beta|rc)\d+)?)
    (?:\+(?P<build>[0-9a-zA-Z.-]*))?
    $
    ```

    NOTE:
    Even if Postgres versions don't support build metadata, the default is to
    parse it. For strict Postgres versions, use `strict = True`.

    Args:
        version (string): a Postgres version string (e.g. `"16.2"`,
            `"17beta1"`, etc).
        strict (bool): `True` doesn't allow build metadata.
        _fail (function): **[TESTING]** mock of the `fail()` function.

    Returns:
        A tuple of strings with the parts that potentially make a Postgres
        version.
    """
    if type(version) != "string":
        return _fail("Invalid Postgres version string: %s" % str(version))

    if version == "":
        return _fail("Empty version string")

    # split and parse build metadata
    parts = version.split("+", 1)
    version = parts[0]
    build = parts[1] if len(parts) > 1 else ()
    build = SemVer.__internal__._parse_identifiers(build)

    prerelease_name = None
    for p in ("alpha", "beta", "rc"):
        if p in version:
            prerelease_name = p

    if prerelease_name:
        minor = None
        major, _, prerelease_num = version.partition(prerelease_name)

        prerelease = (prerelease_name, prerelease_num)

        if not utils.is_uint(prerelease_num):
            msg = "Invalid Postgres prerelease: %s"
            _fail(msg % "".join(prerelease))
    else:
        prerelease = ()
        major, _, minor = version.partition(".")

    if strict and build:
        _fail("Invalid Postgres strict version: %s" % version)

    return major or None, minor or None, prerelease, build

def _validate(
        major,
        minor,
        prerelease,
        build,
        partial = False,
        wildcards = (),
        allow_empty = False,
        strict = False,
        _fail = fail):
    # NOTE:
    # When calling semver.validate we mock fail so that if the validation
    # fails, we can capture the failure and convert it into a "pgver failure"
    def _capture_fail(msg):
        return msg

    res = SemVer.__internal__._validate(
        major = major,
        minor = minor,
        patch = None,
        prerelease = prerelease,
        build = build,
        partial = True,
        wildcards = wildcards,
        allow_empty = allow_empty,
        _fail = _capture_fail,
    )

    if type(res) == "string":
        # There was an error in SemVer.validate(), convert to a
        # Postgres error and fail again
        res = res.replace("semantic version", "Postgres version")
        res = res.replace("minor/patch", "minor")
        return _fail(res)

    major, minor, _, prerelease, build, _ = res

    if strict and build:
        return _fail("Invalid Postgres version")

    has_major = major != None
    has_prerelease = prerelease != ()
    has_minor = minor != None and not has_prerelease
    allowed_partial = partial or bool(wildcards)

    # If not allowed_partial we must have either a major + minor version or a
    # major + prerelease version

    # Case 1: major + minor version (e.g., 16.0)
    if has_major and has_minor and not has_prerelease:
        return major, minor, prerelease, build, False

    # Case 2: major + prerelease (e.g. 16alpha1)
    if has_major and not has_minor and has_prerelease:
        return major, 0, prerelease, build, False

    # if partials are allowed, it's easier to check for the valid cases:
    if allowed_partial:
        # Case 3: major only (e.g. 16 or 16 and wildcards, 16.*, 16.x, etc)
        if has_major and not has_minor and not has_prerelease:
            return major, minor, prerelease, build, allowed_partial

        # Case 4: Wildcard-only version (e.g. *)
        if not has_major and not has_minor and not has_prerelease:
            return major, minor, prerelease, build, allowed_partial

    # If none matched, it's invalid
    return _fail("Invalid Postgres version")

def _to_str(self):
    """
    Converts the `PgVer` `struct` into a Postgres version string.

    Args:
        self (`PgVer`): A `PgVer` `struct`.

    Returns:
        A string representation of the version, following the Postgres format:

        `major[.minor|prerelease]`

        Note that, to support partial versions, the `minor` and `prerelease`
        components are included only if not `None` or `()`, respectively.

        Also, if the version is not strict and there's metadata, it'll be
        added similar to SemVer versions.
    """
    version = "%d" % self.major

    if self.prerelease == () and self.minor != None:
        version += ".%d" % self.minor
    elif self.prerelease != ():
        version += "".join([str(p) for p in self.prerelease])

    if self.build:
        version += "+%s" % ".".join([str(p) for p in self.build])

    return version

def _new(
        major,
        minor = None,
        prerelease = (),
        build = (),
        partial = False,
        wildcards = (),
        strict = False,
        _fail = fail):
    """
    Constructs a `PgVer` `struct`.

    Args:
        major (string): Postgres major version (e.g. `"16"`)
        minor (string): Postgres minor version (e.g. `"2"`)
        prerelease (tuple[string]): Postgres prerelease version (e.g. `("beta",
            "1")`)
        build (tuple[string]): build metadata (e.g. `("build", "001")`).
        partial (bool): whether to accept partial versions (e.g. `"16"` instead
            of `"16.0"`)
        wildcards (tuple[string]): Strings allowed as wildcards in place of a
            normal version number field (e.g. if `wildcards` is set to `("x",
            "*")` then `"16.x"` or `"16.*"` is equivalent to `"16"` with
            `partial = True`).
        strict (bool): `True` doesn't allow build metadata.
        _fail (function): **[TESTING]** mock of the `fail()` function

    Returns:
        A `PgVer` `struct`.
    """
    fields = _validate(
        major,
        minor,
        prerelease,
        build,
        partial = partial,
        wildcards = wildcards,
        strict = strict,
        _fail = _fail,
    )

    if _fail != fail and type(fields) == "string":
        # testing: _fail returned an error string
        return fields

    major, minor, prerelease, build, partial = fields
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
        prerelease = prerelease,
        build = build,
    )

    self = struct(**self_dict)

    self_dict |= dict(
        to_str = lambda: _to_str(self),
        has = lambda level: _has(level),
    )

    self_dict |= comparing.new(self_dict)
    self_dict |= bumping.new(self_dict)
    self_dict |= truncating.new(self_dict)

    return struct(**self_dict)

def _parse(
        version,
        partial = False,
        wildcards = (),
        strict = False,
        _fail = fail):
    """
    Parses a Postgres version string into a `PgVer` `struct`.

    Args:
        version (str): A Postgres version string (e.g. `"16.2"`, `"17beta1"`,
            etc).
        partial (bool): Whether to accept partial versions (e.g. `"16"` instead
            of `"16.0"`)
        wildcards (tuple[string]): Strings allowed as wildcards in place of a
            normal version number field (e.g. if `wildcards` is set to `("x",
            "*")` then `"16.x"` or `"16.*"` is equivalent to `"16"` with
            `partial = True`).
        strict (bool): `True` doesn't allow build metadata.
        _fail (function): **[TESTING]** Mock of the `fail()` function

    Returns:
        A `PgVer` `struct`.
    """
    if _is(version):
        return version

    res = _parse_re(version, strict = strict, _fail = _fail)

    if _fail != fail and type(res) == "string":
        # testing: _fail returned an error string
        return res

    return _new(
        partial = partial,
        wildcards = wildcards,
        strict = strict,
        _fail = _fail,
        *res
    )

def _compare(v1, v2):
    """
    Compares two Postgres versions.

    Args:
        v1 (string): A Postgres version string (e.g. `"16.2"`) or a `PgVer`
            `struct`.
        v2 (string): Another Postgres version string or a `PgVer` `struct`.

    Returns:
        An integer indicating the relative order of `v1` vs `v2`:
        - `-1` if `v1 < v2`
        - `0` if `v1 == v2`
        - `1` if `v1 > v2`
    """
    return SemVer.compare(v1, v2, _parse = _parse)

def _sorted(versions, reverse = False):
    """
    Sorts a list of Postgres version strings.

    Args:
        versions (list[string]): A list of Postgres version strings (e.g.
            `"16.2"`) or `PgVer` `struct`s.
        reverse (bool): If `True`, sorts in descending order. Defaults to
            `False` (ascending).

    Returns:
        A new list of `PgVer` `struct`s, sorted according to Postgres version
        precedence.
    """
    return SemVer.sorted(versions, reverse = reverse)

def _is(value):
    """
    Checks whether the given value is a `PgVer` `struct`.

    Args:
        value: Any value to check.

    Returns:
        `True` if the value is a `PgVer` struct, `False` otherwise.
    """
    return utils.is_(value, __CLASS__)

def _has(field):
    """
    Checks whether the given field is a valid `PgVer` `struct` field.

    Args:
        field: The field name.

    Returns:
        `True` if the value is a valid `PgVer` struct field, `False` otherwise.
    """
    return field in _FIELDS

def _parse_spec(version, wildcards, _fail = fail):
    if version[-1] in ("-", "+"):
        version = version[:-1]

    parts = _parse_re(version, _fail = _fail)

    if _fail != fail and type(parts) == "string":
        # testing: _fail returned an error string
        return parts

    major, minor, prerelease, build = parts

    empty_values = wildcards + [None]

    parts = _validate(
        major,
        minor,
        prerelease,
        build,
        wildcards = empty_values,
        allow_empty = True,
        _fail = _fail,
    )

    if _fail != fail and type(parts) == "string":
        # testing: _fail returned an error string
        return parts

    major, minor, prerelease, build, _ = parts

    major = None if major in empty_values else major
    minor = None if minor in empty_values else minor

    if prerelease and all([p == None for p in (major, minor)]):
        return _fail("Invalid version in spec expression: %r" % version)

    patch = 0

    return major, minor, patch, prerelease, build

pgver = struct(
    new = _new,
    parse = _parse,
    parse_spec = _parse_spec,
    compare = _compare,
    sorted = _sorted,
    is_ = _is,
    has = _has,
    __test__ = struct(
        _parse_re = _parse_re,
    ),
)
