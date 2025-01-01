# `module_name`

[![pre-commit](
    ../../actions/workflows/pre-commit.yaml/badge.svg
)](../../actions/workflows/pre-commit.yaml)
[![CI](
    ../../actions/workflows/ci.yaml/badge.svg
)](../../actions/workflows/ci.yaml)

Bazel module to <DO_SOMETHING>.

## 📦 Install

First, make sure you are running Bazel with [Bzlmod]. Then, add the module as a
dependency in your `MODULE.bazel`:

```starlark
bazel_dep(name = "module_name", version = "<VERSION>")
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
    module_name = "module_name",
    integrity = "",  # TODO: copy the SRI hash that Bazel prints when fetching
    strip_prefix = "bazel_module_name-%s" % REF.strip("v"),
    urls = ["https://github.com/<OWNER>/bazel_module_name/archive/%s.tar.gz" % REF],
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

<MORE_INFO>

## 📄 [Docs]

For more details about <SOME_STUFF>, check the documentation:

<MORE_DOCS>

## 💡 Contributing

Please feel free to open [issues] and [PRs], contributions are always welcome!
See [CONTRIBUTING.md] for more info on how to work with this repo.

[Bzlmod]: https://bazel.build/external/migration
[CONTRIBUTING.md]: CONTRIBUTING.md
[Docs]: docs/README.md
[PRs]: ../../pulls
[`archive_override`]: https://bazel.build/rules/lib/globals/module#archive_override
[issues]: ../../issues
[non-registry override]: https://bazel.build/external/module#non-registry_overrides
