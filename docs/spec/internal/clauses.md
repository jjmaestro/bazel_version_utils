<!-- Generated with Stardoc: http://skydoc.bazel.build -->

# `Clauses`

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

## Exposed types

* `clauses.Always`: *always* matches any version.
* `clauses.Never`: *never* matches any version.
* `clauses.Range`: matches versions according to version-aware comparison
  operators (`==`, `!=`, `<`, `>`, etc).
* `clauses.AllOf`: matches if *all* nested clauses match.
* `clauses.AnyOf`: matches if *any* nested clause matches.

Each `clause` has the following methods:
* `.match(version)`: checks if the clause matches a given version.
* `.and_()` and `.or_()`: logical composition of clauses.
* `.simplify()`: reduces nested structures.
* `.repr()` / `.pretty()`: stringified representations for debugging.

> [!NOTE]
> This module is intended for internal use and is NOT part of a public or
> stable API.

<a id="allof.new"></a>

## allof.new

<pre>
allof.new(<a href="#allof.new-_fail">_fail</a>, <a href="#allof.new-clauses_">clauses_</a>)
</pre>



**PARAMETERS**


| Name  | Description | Default Value |
| :------------- | :------------- | :------------- |
| <a id="allof.new-_fail"></a>_fail |  <p align="center"> - </p>   |  `<built-in function fail>` |
| <a id="allof.new-clauses_"></a>clauses_ |  <p align="center"> - </p>   |  none |


<a id="always.new"></a>

## always.new

<pre>
always.new(<a href="#always.new-_fail">_fail</a>)
</pre>



**PARAMETERS**


| Name  | Description | Default Value |
| :------------- | :------------- | :------------- |
| <a id="always.new-_fail"></a>_fail |  <p align="center"> - </p>   |  `<built-in function fail>` |


<a id="anyof.new"></a>

## anyof.new

<pre>
anyof.new(<a href="#anyof.new-_fail">_fail</a>, <a href="#anyof.new-clauses_">clauses_</a>)
</pre>



**PARAMETERS**


| Name  | Description | Default Value |
| :------------- | :------------- | :------------- |
| <a id="anyof.new-_fail"></a>_fail |  <p align="center"> - </p>   |  `<built-in function fail>` |
| <a id="anyof.new-clauses_"></a>clauses_ |  <p align="center"> - </p>   |  none |


<a id="clause.new"></a>

## clause.new

<pre>
clause.new(<a href="#clause.new-self_dict">self_dict</a>, <a href="#clause.new-_fail">_fail</a>)
</pre>



**PARAMETERS**


| Name  | Description | Default Value |
| :------------- | :------------- | :------------- |
| <a id="clause.new-self_dict"></a>self_dict |  <p align="center"> - </p>   |  none |
| <a id="clause.new-_fail"></a>_fail |  <p align="center"> - </p>   |  `<built-in function fail>` |


<a id="clauses.AllOf.new"></a>

## clauses.AllOf.new

<pre>
clauses.AllOf.new(<a href="#clauses.AllOf.new-_fail">_fail</a>, <a href="#clauses.AllOf.new-clauses_">clauses_</a>)
</pre>



**PARAMETERS**


| Name  | Description | Default Value |
| :------------- | :------------- | :------------- |
| <a id="clauses.AllOf.new-_fail"></a>_fail |  <p align="center"> - </p>   |  `<built-in function fail>` |
| <a id="clauses.AllOf.new-clauses_"></a>clauses_ |  <p align="center"> - </p>   |  none |


<a id="clauses.Always.new"></a>

## clauses.Always.new

<pre>
clauses.Always.new(<a href="#clauses.Always.new-_fail">_fail</a>)
</pre>



**PARAMETERS**


| Name  | Description | Default Value |
| :------------- | :------------- | :------------- |
| <a id="clauses.Always.new-_fail"></a>_fail |  <p align="center"> - </p>   |  `<built-in function fail>` |


<a id="clauses.AnyOf.new"></a>

## clauses.AnyOf.new

<pre>
clauses.AnyOf.new(<a href="#clauses.AnyOf.new-_fail">_fail</a>, <a href="#clauses.AnyOf.new-clauses_">clauses_</a>)
</pre>



**PARAMETERS**


| Name  | Description | Default Value |
| :------------- | :------------- | :------------- |
| <a id="clauses.AnyOf.new-_fail"></a>_fail |  <p align="center"> - </p>   |  `<built-in function fail>` |
| <a id="clauses.AnyOf.new-clauses_"></a>clauses_ |  <p align="center"> - </p>   |  none |


<a id="clauses.Never.new"></a>

## clauses.Never.new

<pre>
clauses.Never.new(<a href="#clauses.Never.new-_fail">_fail</a>)
</pre>



**PARAMETERS**


| Name  | Description | Default Value |
| :------------- | :------------- | :------------- |
| <a id="clauses.Never.new-_fail"></a>_fail |  <p align="center"> - </p>   |  `<built-in function fail>` |


<a id="clauses.Range.new"></a>

## clauses.Range.new

<pre>
clauses.Range.new(<a href="#clauses.Range.new-operator">operator</a>, <a href="#clauses.Range.new-target">target</a>, <a href="#clauses.Range.new-cls_name">cls_name</a>, <a href="#clauses.Range.new-prerelease_policy">prerelease_policy</a>, <a href="#clauses.Range.new-build_policy">build_policy</a>, <a href="#clauses.Range.new-_fail">_fail</a>)
</pre>



**PARAMETERS**


| Name  | Description | Default Value |
| :------------- | :------------- | :------------- |
| <a id="clauses.Range.new-operator"></a>operator |  <p align="center"> - </p>   |  none |
| <a id="clauses.Range.new-target"></a>target |  <p align="center"> - </p>   |  none |
| <a id="clauses.Range.new-cls_name"></a>cls_name |  <p align="center"> - </p>   |  `"semver"` |
| <a id="clauses.Range.new-prerelease_policy"></a>prerelease_policy |  <p align="center"> - </p>   |  `None` |
| <a id="clauses.Range.new-build_policy"></a>build_policy |  <p align="center"> - </p>   |  `None` |
| <a id="clauses.Range.new-_fail"></a>_fail |  <p align="center"> - </p>   |  `<built-in function fail>` |


<a id="clauses.isinstance"></a>

## clauses.isinstance

<pre>
clauses.isinstance(<a href="#clauses.isinstance-other">other</a>, <a href="#clauses.isinstance-__classes__">__classes__</a>)
</pre>



**PARAMETERS**


| Name  | Description | Default Value |
| :------------- | :------------- | :------------- |
| <a id="clauses.isinstance-other"></a>other |  <p align="center"> - </p>   |  none |
| <a id="clauses.isinstance-__classes__"></a>__classes__ |  <p align="center"> - </p>   |  none |


<a id="matcher.new"></a>

## matcher.new

<pre>
matcher.new(<a href="#matcher.new-self_dict">self_dict</a>, <a href="#matcher.new-_fail">_fail</a>)
</pre>



**PARAMETERS**


| Name  | Description | Default Value |
| :------------- | :------------- | :------------- |
| <a id="matcher.new-self_dict"></a>self_dict |  <p align="center"> - </p>   |  none |
| <a id="matcher.new-_fail"></a>_fail |  <p align="center"> - </p>   |  `<built-in function fail>` |


<a id="never.new"></a>

## never.new

<pre>
never.new(<a href="#never.new-_fail">_fail</a>)
</pre>



**PARAMETERS**


| Name  | Description | Default Value |
| :------------- | :------------- | :------------- |
| <a id="never.new-_fail"></a>_fail |  <p align="center"> - </p>   |  `<built-in function fail>` |


<a id="range_.new"></a>

## range_.new

<pre>
range_.new(<a href="#range_.new-operator">operator</a>, <a href="#range_.new-target">target</a>, <a href="#range_.new-cls_name">cls_name</a>, <a href="#range_.new-prerelease_policy">prerelease_policy</a>, <a href="#range_.new-build_policy">build_policy</a>, <a href="#range_.new-_fail">_fail</a>)
</pre>



**PARAMETERS**


| Name  | Description | Default Value |
| :------------- | :------------- | :------------- |
| <a id="range_.new-operator"></a>operator |  <p align="center"> - </p>   |  none |
| <a id="range_.new-target"></a>target |  <p align="center"> - </p>   |  none |
| <a id="range_.new-cls_name"></a>cls_name |  <p align="center"> - </p>   |  `"semver"` |
| <a id="range_.new-prerelease_policy"></a>prerelease_policy |  <p align="center"> - </p>   |  `None` |
| <a id="range_.new-build_policy"></a>build_policy |  <p align="center"> - </p>   |  `None` |
| <a id="range_.new-_fail"></a>_fail |  <p align="center"> - </p>   |  `<built-in function fail>` |


