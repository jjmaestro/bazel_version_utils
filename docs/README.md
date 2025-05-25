# 📄 `version_utils`

## `version/`

* [`semver`]: for [semantic versions].
* [`pgver`]: for [Postgres versions].

## `spec/`

* [`spec`]: for semantic version requirement specifications.

## `spec/internal/`

* `spec` syntaxes:
  * [`SYNTAX.SIMPLE`]: an easy, natural requirement syntax somewhat inspired by
    Python's [PEP 440] (e.g. `>=0.1.1,<0.3.0`). This is the default.
  * [`SYNTAX.NPM`]: the [NPM-style `node-semver` `Ranges` syntax] (e.g. `>=0.1.1
    <0.1.3 || 2.x`).
* [`clauses`]: internal framework for building and evaluating logical
  expressions (clauses) over version constraints.

[NPM-style `node-semver` `Ranges` syntax]: https://github.com/npm/node-semver?tab=readme-ov-file#ranges
[PEP 440]: https://peps.python.org/pep-0440/
[Postgres versions]: https://www.postgresql.org/support/versioning/
[`SYNTAX.NPM`]: spec/internal/npm.md
[`SYNTAX.SIMPLE`]: spec/internal/simple.md
[`clauses`]: spec/internal/clauses.md
[`pgver`]: version/pgver.md
[semantic versions]: https://semver.org
[`semver`]: version/semver.md
[`spec`]: spec/spec.md
