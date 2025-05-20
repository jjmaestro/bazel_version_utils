# [`SYNTAX.SIMPLE`] version requirement specification

This syntax is a natural and easy requirement specification somewhat inspired
by Python's [PEP 440] (e.g. `>=0.1.1,<0.3.0`). This is the default.

## Structure

This syntax is a port of [`python-semanticversion`'s `SimpleSpec`]. The syntax
uses the following rules:

* A specification expression is a list of clauses separated by a comma (`,`)
* A version is matched by an expression if, and only if, it matches *all*
  clauses in the expression
* A clause of `*` matches every valid version

### Equality clauses

* A clause of `==0.1.2` will match version `0.1.2` and any version
  differing only through its build number (`0.1.2+b42` matches).
* A clause of `==0.1.2+b42` will only match that specific version:
  `0.1.2+b43` and `0.1.2` are excluded.
* A clause of `==0.1.2+` will only match that specific version: `0.1.2+b42`
  is excluded.
* A clause of `!=0.1.2` will prevent all versions with the same
  major/minor/patch combination: `0.1.2-rc.1` and `0.1.2+b42` are excluded'.
* A clause of `!=0.1.2-` will only prevent build variations of that version:
  `0.1.2-rc.1` is included, but not `0.1.2+b42`.
* A clause of `!=0.1.2+` will exclude only that exact version: `0.1.2-rc.1` and
  `0.1.2+b42` are included.
* Only a `==` or `!=` clause may contain build-level metadata: `==1.2.3+b42` is
  valid, `>=1.2.3+b42` isn't.

### Comparison clauses

* A clause of `<0.1.2` will match versions strictly below `0.1.2`, excluding
  prereleases of `0.1.2`: `0.1.2-rc.1` is excluded.
* A clause of `<0.1.2-` will match versions strictly below `0.1.2`, including
  prereleases of `0.1.2`: `0.1.2-rc.1` is included.
* A clause of `<0.1.2-rc.3` will match versions strictly below `0.1.2-rc.3`,
  including prereleases: `0.1.2-rc.2` is included.
* A clause of `<=XXX` will match versions that match `<XXX` or `==XXX`.
* A clause of `>0.1.2` will match versions strictly above `0.1.2`, including
  all prereleases of `0.1.3`.
* A clause of `>0.1.2-rc.3` will match versions strictly above `0.1.2-rc.3`,
  including matching prereleases of `0.1.2`: `0.1.2-rc.10` is included.
* A clause of `>=XXX` will match versions that match `>XXX` or `==XXX`.

### Wildcards

* A clause of `==0.1.*` is equivalent to `>=0.1.0,<0.2.0`.
* A clause of `>=0.1.*` is equivalent to `>=0.1.0`.
* A clause of `==1.*` or `==1.*.*` is equivalent to `>=1.0.0,<2.0.0`.
* A clause of `>=1.*` or `>=1.*.*` is equivalent to `>=1.0.0`.
* A clause of `==*` maps to `>=0.0.0`.
* A clause of `>=*` maps to `>=0.0.0`.

### Extensions

Additionally, it supports extensions from specific packaging platforms:

PyPI-style `compatible release clauses`_:
* `~=2.2` means "Any release between `2.2.0` and `3.0.0`".
* `~=1.4.5` means "Any release between `1.4.5` and `1.5.0`".

NPM-style specs:
* `~1.2.3` means "Any release between `1.2.3` and `1.3.0`".
* `^1.3.4` means "Any release between `1.3.4` and `2.0.0`".


[PEP 440]: https://peps.python.org/pep-0440/
[`python-semanticversion`'s `SimpleSpec`]: https://python-semanticversion.readthedocs.io/en/latest/reference.html#semantic_version.SimpleSpec
[`SYNTAX.SIMPLE`]: ../../../spec/internal/simple.bzl
