"""
# `spec`

Bazel extension to work with version requirement specifications.

A version requirement specification is a formal expression that defines
acceptable version(s) of a software package or dependency. It's mostly used by
package managers to determine whether a specific version of a dependency
satisfies the constraints defined by a consuming project.

These specifications usually allow developers to specify wildcard versions,
ranges of valid versions, etc. The syntax and semantics vary between
ecosystems, but all serve the same core purpose: to express compatibility or
constraints with respect to version numbers.

This extension currently supports two syntaxes:

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

[NPM-style `node-semver` `Ranges` syntax]: https://github.com/npm/node-semver?tab=readme-ov-file#ranges
[PEP 440]: https://peps.python.org/pep-0440/
[`spec/internal/simple`]: docs/spec/internal/simple.md
[`SYNTAX.SIMPLE`]: internal/simple.md
[`SYNTAX.NPM`]: internal/npm.md
"""

load("//spec/internal:npm.bzl", NPMParser = "npmparser")
load("//spec/internal:simple.bzl", SimpleParser = "simpleparser")
load("//spec/internal:utils.bzl", "isinstance")
load("//version:semver.bzl", SemVer = "semver")

SYNTAX = struct(
    SIMPLE = "simple",
    NPM = "npm",
)

def _new(expression, syntax = SYNTAX.SIMPLE, _fail = fail):
    """
    Constructs a `Spec` `struct` from the given version requirements specification.

    A version requirements specification is a set of constraints that
    compatible versions have to fulfill. Internally, the specification is
    translated into a set of `Clause`s.

    #### EXAMPLE

    ```starlark
    load("@version_utils//spec:spec.bzl", "spec")

    simple = spec.new(">=0.1.0,<0.4.0")

    npm = spec.new(">=0.1.0 <0.3.0", syntax = spec.SYNTAX.NPM)
    ```

    Args:
        expression (string): The version requirements specification string.
        syntax (SYNTAX): The `SYNTAX` of the specification. One of
            [`SYNTAX.SIMPLE`] (e.g. `>=0.1.1,<0.3.0`) or [`SYNTAX.NPM`] (e.g.
            `>=0.1.1 <0.1.3 || 2.x`). Defaults to `SYNTAX.SIMPLE`.
        _fail (function): **[TESTING]** Mock of the `fail()` function.

    Returns:
        A `Spec` `struct`.
    """

    def _match(version):
        """
        Checks whether the given version satisfies the spec.
        """
        return self.clause.match(version)

    def _filter(versions):
        """
        Filters the versions in the iterable of versions that match the spec.
        """
        return [
            SemVer.parse(version)
            for version in versions
            if _match(version)
        ]

    def _select(versions):
        """
        Selects the highest version in the versions iterable that matches the spec.
        """
        options = _filter(versions)

        if not options:
            return None

        max_ = options[0]
        for option in options[1:]:
            if option.gt(max_):
                max_ = option

        return max_

    def _eq(other, _fail = fail):
        if not isinstance(other, self.__class__):
            return _fail("NotImplemented")

        return self.clause.eq(other.clause)

    def _to_str():
        return self.expression

    def _repr():
        return "<%s:%s %r>" % (self.__class__, self.syntax.upper(), self.expression)

    if syntax == SYNTAX.SIMPLE:
        parser = SimpleParser.new(_fail = _fail)
    elif syntax == SYNTAX.NPM:
        parser = NPMParser.new(_fail = _fail)
    else:
        return _fail("Unknown syntax: %s" % syntax)

    clause = parser.parse(expression)

    if _fail != fail and type(clause) == "string":
        # testing: _fail returned an error string
        return clause

    self = struct(
        __class__ = "Spec",
        syntax = syntax,
        expression = expression,
        clause = clause,
        filter = _filter,
        select = _select,
        match = _match,
        eq = _eq,
        to_str = _to_str,
        repr = _repr,
    )

    return self

spec = struct(
    SYNTAX = SYNTAX,
    new = _new,
)
