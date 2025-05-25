<!-- Generated with Stardoc: http://skydoc.bazel.build -->

# `version`

Bazel extension to work with version schemes.

Supported version schemes:

* [semantic (`SemVer`)]: e.g. `1.0.2-rc.1+b20250115`.
* [Postgres (`PgVer`)]: e.g. `16.0`, `17rc1`.

[semantic (`SemVer`)]: semver.md
[Postgres (`PgVer`)]: pgver.md

<a id="version.new"></a>

## version.new

<pre>
version.new(<a href="#version.new-scheme">scheme</a>, <a href="#version.new-_fail">_fail</a>)
</pre>



**PARAMETERS**


| Name  | Description | Default Value |
| :------------- | :------------- | :------------- |
| <a id="version.new-scheme"></a>scheme |  <p align="center"> - </p>   |  none |
| <a id="version.new-_fail"></a>_fail |  <p align="center"> - </p>   |  `<built-in function fail>` |


