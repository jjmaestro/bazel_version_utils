# [`Clauses`]

Internal framework for building and evaluating logical expressions (clauses)
over version constraints.

This module defines a flexible clause system for version matching, supporting
constant matchers (`Always`, `Never`), comparison-based constraints (`Range`)
and logical composition (`AllOf`, `AnyOf`).

Clauses can be evaluated against versions (`match(version)`), simplified and/or
logically combined with `and`/`or` operators,

The typical use case is parsing and evaluating complex version requirement
expressions in package managers, version resolution tooling, build systems,
etc.

## `Clause` types

* `Always`: *always* matches any version.
* `Never`: *never* matches any version.
* `Range`: matches versions according to version-aware comparison operators
  (`==`, `!=`, `<`, `>`, etc).
* `AllOf`: matches if *all* nested clauses match.
* `AnyOf`: matches if *any* nested clause matches.

Each `Clause` has the following methods:
* `.match(version)`: checks if the clause matches a given version.
* `.and_()` and `.or_()`: logical composition of clauses.
* `.simplify()`: reduces nested structures.
* `.repr()` / `.pretty()`: stringified representations for debugging.

> [!NOTE]
> This module is intended for internal use and is NOT part of a public or
> stable API.

[`Clauses`]: ../../../spec/internal/clauses.bzl
