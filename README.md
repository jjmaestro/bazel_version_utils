# `version_utils`

[![pre-commit](
    ../../actions/workflows/pre-commit.yaml/badge.svg
)](../../actions/workflows/pre-commit.yaml)

Bazel module to work with version schemes.

It currently supports [semantic versions]. Ideally, it will eventually expand
to support additional versions (e.g. [Debian versions]).

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

## 📄 [Docs]

For more details about each component, check the documentation:

* [`version/semver`]: for [semantic versions].

## 💡 Contributing

Please feel free to open [issues] and [PRs], contributions are always welcome!
See [CONTRIBUTING.md] for more info on how to work with this repo.

## 🫶 Acknowledgements

This Bazel module began as a Starlark port of [python-semanticversion]. Credit
and thanks to its original author, [@rbarrois]!

[CONTRIBUTING.md]: CONTRIBUTING.md
[Debian versions]: https://www.debian.org/doc/debian-policy/ch-controlfields.html#version
[Docs]: docs/README.md
[PRs]: ../../pulls
[issues]: ../../issues
[python-semanticversion]: https://github.com/rbarrois/python-semanticversion
[@rbarrois]: https://github.com/rbarrois
[semantic versions]: https://semver.org
[`version/semver`]: docs/version/semver.md
