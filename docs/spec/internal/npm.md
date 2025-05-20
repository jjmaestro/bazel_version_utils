<!-- Generated with Stardoc: http://skydoc.bazel.build -->

# `SYNTAX.NPM` version requirement specification

See [NPM-style `node-semver` `Ranges` syntax].

[NPM-style `node-semver` `Ranges` syntax]: https://github.com/npm/node-semver?tab=readme-ov-file#ranges

<a id="npmparser.new"></a>

## npmparser.new

<pre>
npmparser.new(<a href="#npmparser.new-_fail">_fail</a>)
</pre>

Constructs a `NpmParser` `struct`.

The `struct` has a `parse()` method that can parse an NPM-style version
requirement specification. It will return a [`Clause`] that can then be
matched against a given version to test if the version satisfies the
requirement specification with `match(version)`.

> [!NOTE]
> This parser is internal and meant to be used in [`Spec`].

[`Clause`]: clauses.md
[`Spec`]: ../spec.md


**PARAMETERS**


| Name  | Description | Default Value |
| :------------- | :------------- | :------------- |
| <a id="npmparser.new-_fail"></a>_fail |  **[TESTING]** Mock of the `fail()` function.   |  `<built-in function fail>` |

**RETURNS**

A `NpmParser` `struct`.


