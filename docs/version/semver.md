<!-- Generated with Stardoc: http://skydoc.bazel.build -->

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

<a id="semver.compare"></a>

## semver.compare

<pre>
semver.compare(<a href="#semver.compare-v1">v1</a>, <a href="#semver.compare-v2">v2</a>, <a href="#semver.compare-_parse">_parse</a>)
</pre>

Compares two semantic versions.

**PARAMETERS**


| Name  | Description | Default Value |
| :------------- | :------------- | :------------- |
| <a id="semver.compare-v1"></a>v1 |  A semantic version string (e.g. `"1.5.2-rc.1-b20"`) or a `SemVer` `struct`.   |  none |
| <a id="semver.compare-v2"></a>v2 |  Another semantic version string or a `SemVer` `struct`.   |  none |
| <a id="semver.compare-_parse"></a>_parse |  **[INTERNAL]** Parser method used to convert strings to SemVer structs.   |  `<function _parse from @@version_utils~//version:semver.bzl>` |

**RETURNS**

An integer indicating the relative order of `v1` vs `v2`:
  - `-1` if `v1 < v2`
  - `0` if `v1 == v2`
  - `1` if `v1 > v2`


<a id="semver.has"></a>

## semver.has

<pre>
semver.has(<a href="#semver.has-field">field</a>)
</pre>

Checks whether the given field is a valid `SemVer` `struct` field.

**PARAMETERS**


| Name  | Description | Default Value |
| :------------- | :------------- | :------------- |
| <a id="semver.has-field"></a>field |  The field name.   |  none |

**RETURNS**

`True` if the value is a valid `SemVer` struct field, `False`
  otherwise.


<a id="semver.is_"></a>

## semver.is_

<pre>
semver.is_(<a href="#semver.is_-value">value</a>)
</pre>

Checks whether the given value is a `SemVer` `struct`.

**PARAMETERS**


| Name  | Description | Default Value |
| :------------- | :------------- | :------------- |
| <a id="semver.is_-value"></a>value |  The value to check.   |  none |

**RETURNS**

`True` if the value is a `SemVer` struct, `False` otherwise.


<a id="semver.new"></a>

## semver.new

<pre>
semver.new(<a href="#semver.new-major">major</a>, <a href="#semver.new-minor">minor</a>, <a href="#semver.new-patch">patch</a>, <a href="#semver.new-prerelease">prerelease</a>, <a href="#semver.new-build">build</a>, <a href="#semver.new-partial">partial</a>, <a href="#semver.new-wildcards">wildcards</a>, <a href="#semver.new-_fail">_fail</a>)
</pre>

Constructs a `SemVer` `struct`.

**PARAMETERS**


| Name  | Description | Default Value |
| :------------- | :------------- | :------------- |
| <a id="semver.new-major"></a>major |  SemVer major string (e.g. `1`).   |  none |
| <a id="semver.new-minor"></a>minor |  SemVer minor string (e.g. `2`).   |  `None` |
| <a id="semver.new-patch"></a>patch |  SemVer patch string (e.g. `3`).   |  `None` |
| <a id="semver.new-prerelease"></a>prerelease |  SemVer prerelease (e.g. `("beta", "1")`).   |  `()` |
| <a id="semver.new-build"></a>build |  SemVer build metadata (e.g. `("build", "001")`).   |  `()` |
| <a id="semver.new-partial"></a>partial |  Whether to accept partial versions (e.g. `1` or `1.0` instead of `1.0.0`).   |  `False` |
| <a id="semver.new-wildcards"></a>wildcards |  Strings allowed as wildcards in place of a normal version number field (e.g. if `wildcards` is set to `("x", "*")` then `"1.x"` or `"1.1.*"` is equivalent to `"1"` or `"1.1"` with `partial = True`, respectively).   |  `()` |
| <a id="semver.new-_fail"></a>_fail |  **[TESTING]** Mock of the fail() function   |  `<built-in function fail>` |

**RETURNS**

A `SemVer` `struct`.


<a id="semver.parse"></a>

## semver.parse

<pre>
semver.parse(<a href="#semver.parse-version">version</a>, <a href="#semver.parse-partial">partial</a>, <a href="#semver.parse-wildcards">wildcards</a>, <a href="#semver.parse-_fail">_fail</a>)
</pre>

Parses a version string into a `SemVer` `struct`.

**PARAMETERS**


| Name  | Description | Default Value |
| :------------- | :------------- | :------------- |
| <a id="semver.parse-version"></a>version |  a semantic version string (e.g. `"1.5.2-rc.1-b20"`)   |  none |
| <a id="semver.parse-partial"></a>partial |  whether to accept partial versions (e.g. `"1"` or `"1.0"` instead of `"1.0.0"`)   |  `False` |
| <a id="semver.parse-wildcards"></a>wildcards |  wildcards allowed in the normal version number fields, if any (e.g. if `wildcards` is set to `("x", "*")` then `"1.x"` or `"1.1.*"` is equivalent to `"1"` or `"1.1"` with `partial = True`, respectively).   |  `()` |
| <a id="semver.parse-_fail"></a>_fail |  **[TESTING]** mock of the fail() function   |  `<built-in function fail>` |

**RETURNS**

A `SemVer` `struct`.


<a id="semver.parse_spec"></a>

## semver.parse_spec

<pre>
semver.parse_spec(<a href="#semver.parse_spec-version">version</a>, <a href="#semver.parse_spec-wildcards">wildcards</a>, <a href="#semver.parse_spec-_fail">_fail</a>)
</pre>



**PARAMETERS**


| Name  | Description | Default Value |
| :------------- | :------------- | :------------- |
| <a id="semver.parse_spec-version"></a>version |  <p align="center"> - </p>   |  none |
| <a id="semver.parse_spec-wildcards"></a>wildcards |  <p align="center"> - </p>   |  none |
| <a id="semver.parse_spec-_fail"></a>_fail |  <p align="center"> - </p>   |  `<built-in function fail>` |


<a id="semver.sorted"></a>

## semver.sorted

<pre>
semver.sorted(<a href="#semver.sorted-versions">versions</a>, <a href="#semver.sorted-reverse">reverse</a>)
</pre>

Sorts a list of semantic version strings.

**PARAMETERS**


| Name  | Description | Default Value |
| :------------- | :------------- | :------------- |
| <a id="semver.sorted-versions"></a>versions |  A list of semantic version strings (e.g. `"1.5.2-rc.1-b20"`) or `SemVer` `struct`s.   |  none |
| <a id="semver.sorted-reverse"></a>reverse |  If `True`, sorts in descending order. Defaults to `False` (ascending).   |  `False` |

**RETURNS**

A new list of `SemVer` `struct`s, sorted according to semantic version
  precedence.


