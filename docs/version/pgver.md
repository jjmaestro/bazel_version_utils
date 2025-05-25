<!-- Generated with Stardoc: http://skydoc.bazel.build -->

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

<a id="pgver.compare"></a>

## pgver.compare

<pre>
pgver.compare(<a href="#pgver.compare-v1">v1</a>, <a href="#pgver.compare-v2">v2</a>)
</pre>

Compares two Postgres versions.

**PARAMETERS**


| Name  | Description | Default Value |
| :------------- | :------------- | :------------- |
| <a id="pgver.compare-v1"></a>v1 |  A Postgres version string (e.g. `"16.2"`) or a `PgVer` `struct`.   |  none |
| <a id="pgver.compare-v2"></a>v2 |  Another Postgres version string or a `PgVer` `struct`.   |  none |

**RETURNS**

An integer indicating the relative order of `v1` vs `v2`:
  - `-1` if `v1 < v2`
  - `0` if `v1 == v2`
  - `1` if `v1 > v2`


<a id="pgver.has"></a>

## pgver.has

<pre>
pgver.has(<a href="#pgver.has-field">field</a>)
</pre>

Checks whether the given field is a valid `PgVer` `struct` field.

**PARAMETERS**


| Name  | Description | Default Value |
| :------------- | :------------- | :------------- |
| <a id="pgver.has-field"></a>field |  The field name.   |  none |

**RETURNS**

`True` if the value is a valid `PgVer` struct field, `False` otherwise.


<a id="pgver.is_"></a>

## pgver.is_

<pre>
pgver.is_(<a href="#pgver.is_-value">value</a>)
</pre>

Checks whether the given value is a `PgVer` `struct`.

**PARAMETERS**


| Name  | Description | Default Value |
| :------------- | :------------- | :------------- |
| <a id="pgver.is_-value"></a>value |  Any value to check.   |  none |

**RETURNS**

`True` if the value is a `PgVer` struct, `False` otherwise.


<a id="pgver.new"></a>

## pgver.new

<pre>
pgver.new(<a href="#pgver.new-major">major</a>, <a href="#pgver.new-minor">minor</a>, <a href="#pgver.new-prerelease">prerelease</a>, <a href="#pgver.new-build">build</a>, <a href="#pgver.new-partial">partial</a>, <a href="#pgver.new-wildcards">wildcards</a>, <a href="#pgver.new-strict">strict</a>, <a href="#pgver.new-_fail">_fail</a>)
</pre>

Constructs a `PgVer` `struct`.

**PARAMETERS**


| Name  | Description | Default Value |
| :------------- | :------------- | :------------- |
| <a id="pgver.new-major"></a>major |  Postgres major version (e.g. `"16"`)   |  none |
| <a id="pgver.new-minor"></a>minor |  Postgres minor version (e.g. `"2"`)   |  `None` |
| <a id="pgver.new-prerelease"></a>prerelease |  Postgres prerelease version (e.g. `("beta", "1")`)   |  `()` |
| <a id="pgver.new-build"></a>build |  build metadata (e.g. `("build", "001")`).   |  `()` |
| <a id="pgver.new-partial"></a>partial |  whether to accept partial versions (e.g. `"16"` instead of `"16.0"`)   |  `False` |
| <a id="pgver.new-wildcards"></a>wildcards |  Strings allowed as wildcards in place of a normal version number field (e.g. if `wildcards` is set to `("x", "*")` then `"16.x"` or `"16.*"` is equivalent to `"16"` with `partial = True`).   |  `()` |
| <a id="pgver.new-strict"></a>strict |  `True` doesn't allow build metadata.   |  `False` |
| <a id="pgver.new-_fail"></a>_fail |  **[TESTING]** mock of the `fail()` function   |  `<built-in function fail>` |

**RETURNS**

A `PgVer` `struct`.


<a id="pgver.parse"></a>

## pgver.parse

<pre>
pgver.parse(<a href="#pgver.parse-version">version</a>, <a href="#pgver.parse-partial">partial</a>, <a href="#pgver.parse-wildcards">wildcards</a>, <a href="#pgver.parse-strict">strict</a>, <a href="#pgver.parse-_fail">_fail</a>)
</pre>

Parses a Postgres version string into a `PgVer` `struct`.

**PARAMETERS**


| Name  | Description | Default Value |
| :------------- | :------------- | :------------- |
| <a id="pgver.parse-version"></a>version |  A Postgres version string (e.g. `"16.2"`, `"17beta1"`, etc).   |  none |
| <a id="pgver.parse-partial"></a>partial |  Whether to accept partial versions (e.g. `"16"` instead of `"16.0"`)   |  `False` |
| <a id="pgver.parse-wildcards"></a>wildcards |  Strings allowed as wildcards in place of a normal version number field (e.g. if `wildcards` is set to `("x", "*")` then `"16.x"` or `"16.*"` is equivalent to `"16"` with `partial = True`).   |  `()` |
| <a id="pgver.parse-strict"></a>strict |  `True` doesn't allow build metadata.   |  `False` |
| <a id="pgver.parse-_fail"></a>_fail |  **[TESTING]** Mock of the `fail()` function   |  `<built-in function fail>` |

**RETURNS**

A `PgVer` `struct`.


<a id="pgver.sorted"></a>

## pgver.sorted

<pre>
pgver.sorted(<a href="#pgver.sorted-versions">versions</a>, <a href="#pgver.sorted-reverse">reverse</a>)
</pre>

Sorts a list of Postgres version strings.

**PARAMETERS**


| Name  | Description | Default Value |
| :------------- | :------------- | :------------- |
| <a id="pgver.sorted-versions"></a>versions |  A list of Postgres version strings (e.g. `"16.2"`) or `PgVer` `struct`s.   |  none |
| <a id="pgver.sorted-reverse"></a>reverse |  If `True`, sorts in descending order. Defaults to `False` (ascending).   |  `False` |

**RETURNS**

A new list of `PgVer` `struct`s, sorted according to Postgres version
  precedence.


