# `version_utils`

[![pre-commit](
    ../../actions/workflows/pre-commit.yaml/badge.svg
)](../../actions/workflows/pre-commit.yaml)

Bazel module to work with version schemes and version requirement
specifications.

It currently supports [semantic versions], as well as semantic version
requirement specifications such as [NPM-style `node-semver` `Ranges` syntax].

Ideally, it will eventually expand to support additional versions (e.g. [Debian
versions] and [Debian version requirements].

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

A semantic version can also be created with named attributes. In that case,
`major`, `minor` and `patch` are *mandatory*, and must be integers:

```starlark
version = semver.new(major = 1, minor = 0, patch = 2)

print(version.major, version.minor, version.patch)
# 1 0 2

version = semver.new(major = 1, minor = 0)
# Error in fail: Invalid semantic version minor/patch value: None
```

<details>

<summary>More info about operating with versions</summary>

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

Versions can be "bumped" in one of the version levels:

```starlark
version = semver.parse('1.0.0+build')

new_v = version.bump("patch")
print(new_v.to_str())
# 1.0.1

new_v = version.bump("minor")
print(new_v.to_str())
# 1.1.0

new_v = version.bump("major")
print(new_v.to_str())
# 2.0.0
```

and can be "truncated" up to the selected level:

```starlark
version = semver.parse('1.2.3-pre.1+build.1')

new_v = version.truncate("build")
print(new_v.to_str())
# 1.2.3-pre.1+build.1

new_v = version.truncate("prerelease")
print(new_v.to_str())
# 1.2.3-pre.1

new_v = version.truncate("patch")
print(new_v.to_str())
# 1.2.3

new_v = version.truncate("minor")
print(new_v.to_str())
# 1.1.0

new_v = version.truncate("major")
print(new_v.to_str())
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

[CONTRIBUTING.md]: CONTRIBUTING.md
[Debian versions]: https://www.debian.org/doc/debian-policy/ch-controlfields.html#version
[Debian version requirements]: https://www.debian.org/doc/debian-policy/ch-relationships.html#syntax-of-relationship-fields
[Docs]: docs/README.md
[NPM-style `node-semver` `Ranges` syntax]: https://github.com/npm/node-semver?tab=readme-ov-file#ranges
[PEP 440]: https://peps.python.org/pep-0440/
[PRs]: ../../pulls
[`SYNTAX.NPM`]: docs/spec/internal/npm.md
[`SYNTAX.SIMPLE`]: docs/spec/internal/simple.md
[issues]: ../../issues
[python-semanticversion]: https://github.com/rbarrois/python-semanticversion
[@rbarrois]: https://github.com/rbarrois
[semantic versions]: https://semver.org
[`spec/spec`]: docs/spec/spec.md
[`version/semver`]: docs/version/semver.md
