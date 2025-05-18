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

Bazel module to work with version schemes.

It currently supports [semantic versions]. Ideally, it will eventually expand
to support additional versions (e.g. [Debian versions]).

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

## 📄 [Docs]

For more details about each component, check the documentation:

* [`version/semver`]: for [semantic versions].

## 💡 Contributing

Please feel free to open [issues] and [PRs], contributions are always welcome!
See [CONTRIBUTING.md] for more info on how to work with this repo.

## 🫶 Acknowledgements

This Bazel module began as a Starlark port of [python-semanticversion]. Credit
and thanks to its original author, [@rbarrois]!

[Bzlmod]: https://bazel.build/external/migration
[CONTRIBUTING.md]: CONTRIBUTING.md
[Debian versions]: https://www.debian.org/doc/debian-policy/ch-controlfields.html#version
[Docs]: docs/README.md
[PRs]: ../../pulls
[`archive_override`]: https://bazel.build/rules/lib/globals/module#archive_override
[issues]: ../../issues
[non-registry override]: https://bazel.build/external/module#non-registry_overrides
[python-semanticversion]: https://github.com/rbarrois/python-semanticversion
[@rbarrois]: https://github.com/rbarrois
[semantic versions]: https://semver.org
[`version/semver`]: docs/version/semver.md
