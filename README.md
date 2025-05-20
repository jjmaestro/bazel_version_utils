<!-- markdownlint-capture -->
<!-- markdownlint-disable MD013 MD033 MD041 -->
<p style="text-align: left;">
    <img src="logo.svg" alt="version_utils logo" title="logo" align="left" height="60" />
</p>
<!-- markdownlint-restore -->

# `version_utils`

[![pre-commit](
    ../../actions/workflows/pre-commit.yaml/badge.svg
)](../../actions/workflows/pre-commit.yaml)
[![CI](
    ../../actions/workflows/ci.yaml/badge.svg
)](../../actions/workflows/ci.yaml)

Bazel module to work with version schemes and version requirement
specifications.

It currently supports [semantic versions], as well as semantic version
requirement specifications such as [NPM-style `node-semver` `Ranges` syntax].

Ideally, it will eventually expand to support additional versions (e.g. [Debian
versions] and [Debian version requirements]).

## 📦 Install

First, make sure you are running Bazel with [Bzlmod]. Then, add the module as a
dependency in your `MODULE.bazel`:

```starlark
bazel_dep(name = "version_utils", version = "<VERSION>")
```

<details>
<summary><h3>Non-registry overrides</h3></summary>

If you need to use a specific commit or version tag from the repo instead of a
version from the registry, add a [non-registry override] in your `MODULE.bazel`
file, e.g. [`archive_override`]:

<!-- markdownlint-capture -->
<!-- markdownlint-disable MD013 -->
```starlark
REF = "v<VERSION>"  # NOTE: can be a repo tag or a commit hash

archive_override(
    module_name = "version_utils",
    integrity = "",  # TODO: copy the SRI hash that Bazel prints when fetching
    strip_prefix = "bazel_version_utils-%s" % REF.strip("v"),
    urls = ["https://github.com/jjmaestro/bazel_version_utils/archive/%s.tar.gz" % REF],
)
```
<!-- markdownlint-restore -->

**NOTE**:
`integrity` is intentionally empty so Bazel will warn and print the SRI hash of
the downloaded artifact. **Leaving it empty is a security risk**. Always verify
the contents of the downloaded artifact, copy the printed hash and update
`MODULE.bazel` accordingly.

</details>

## 🚀 Getting Started

### `version`

This package provides extensions to work with different version schemes.
Currently, it only supports one version scheme: [semantic versions].

A semantic version can be created by parsing a string:

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

It can also be created by specifying its named fields:

```starlark
version = semver.new(major = 1, minor = 0, patch = 2)

print(version.major, version.minor, version.patch)
# 1 0 2

version = semver.new(major = 1, minor = 0)
# Error in fail: Invalid semantic version minor/patch value: None
```

<details>

<summary><h4>Working with versions</h4></summary>

Versions can be compared:

```starlark
v1 = semver.parse('0.1.1')
v2 = semver.parse('0.1.2')
v3 = semver.parse('0.1.1-alpha.1')

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

Versions can be incremented ("bumped") in any of their version fields:

```starlark
version = semver.parse('1.0.0+build')

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

and can be truncated up to any of their version fields:

```starlark
version = semver.parse('1.2.3-pre.1+build.1')

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

</details>

### `spec`: Version Requirement Specifications

This package provides a `spec` extension to work with version requirement
specifications.

It currently supports two syntaxes:

* [`SYNTAX.SIMPLE`]: an easy, natural requirement syntax somewhat inspired by
  Python's [PEP 440] (e.g. `>=0.1.1,<0.3.0`). This is the default.
* [`SYNTAX.NPM`]: the [NPM-style `node-semver` `Ranges` syntax] (e.g. `>=0.1.1
  <0.1.3 || 2.x`).

To begin, create a new `Spec` `struct`:

```starlark
load("@version_utils//spec:spec.bzl", "spec")

simple = spec.new(">=0.1.0,<0.4.0")

npm = spec.new(">=0.1.0 <0.3.0", syntax = spec.SYNTAX.NPM)
```

The `Spec` `struct` has three methods:

* `spec.match`: checks whether the given version satisfies the version
  requirement specification:

```starlark
version = semver.parse("0.2.0")

print(simple.match(version))
# True

version = semver.parse("0.4.0")

print(simple.match(version))
# False
```

* `spec.filter`: filters the versions in the iterable of versions that match
  the version requirements:

```starlark
versions = [semver.parse("0.%d.0" % i) for i in range(6)]

for v in simple.filter(versions):
    print(v.to_str())
# 0.1.0
# 0.2.0
# 0.3.0

for v in npm.filter(versions):
    print(v.to_str())
# 0.1.0
# 0.2.0
```

* `spec.select`: selects the highest version from an iterable of versions that
  matches the version requirements:

```starlark
versions = [semver.parse("0.%d.0" % i) for i in range(6)]

v = npm.select(versions)

print(v.to_str())
# 0.2.0
```

## 📄 [Docs]

For more details about each component, check the documentation:

* [`version/semver`]: for [semantic versions].
* [`spec/spec`]: for version requirement specifications.

## 💡 Contributing

Please feel free to open [issues] and [PRs], contributions are always welcome!
See [CONTRIBUTING.md] for more info on how to work with this repo.

## 🫶 Acknowledgements

This Bazel module began as a Starlark port of [python-semanticversion]. Credit
and thanks to its original author, [@rbarrois]!

[Bzlmod]: https://bazel.build/external/migration
[CONTRIBUTING.md]: CONTRIBUTING.md
[Debian versions]: https://www.debian.org/doc/debian-policy/ch-controlfields.html#version
[Debian version requirements]: https://www.debian.org/doc/debian-policy/ch-relationships.html#syntax-of-relationship-fields
[Docs]: docs/README.md
[NPM-style `node-semver` `Ranges` syntax]: https://github.com/npm/node-semver?tab=readme-ov-file#ranges
[PEP 440]: https://peps.python.org/pep-0440/
[PRs]: ../../pulls
[`SYNTAX.NPM`]: docs/spec/internal/npm.md
[`SYNTAX.SIMPLE`]: docs/spec/internal/simple.md
[`archive_override`]: https://bazel.build/rules/lib/globals/module#archive_override
[issues]: ../../issues
[non-registry override]: https://bazel.build/external/module#non-registry_overrides
[python-semanticversion]: https://github.com/rbarrois/python-semanticversion
[@rbarrois]: https://github.com/rbarrois
[semantic versions]: https://semver.org
[`spec/spec`]: docs/spec/spec.md
[`version/semver`]: docs/version/semver.md
