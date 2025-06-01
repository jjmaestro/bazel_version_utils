"""
spec/simple.bzl unit tests for PgVer

Mirrors tests/spec/spec_simple_semver.bzl for PgVer versions
"""

load("@bazel_skylib//lib:unittest.bzl", "asserts", "unittest")
load("//spec:spec.bzl", Spec = "spec")

# buildifier: disable=bzl-visibility
load("//spec/internal:simple.bzl", SimpleParser = "simpleparser")
load("//tests:mock.bzl", Mock = "mock")
load("//tests:suite.bzl", _test_suite = "test_suite")
load("//version:version.bzl", Version = "version")

def _invalid_spec_impl(ctx):
    def is_error(res):
        errors = (
            "Empty spec",
            "Can't find a valid spec operator",
            "Invalid spec expression",
            "Invalid Postgres version",
        )

        for error in errors:
            if res.startswith(error):
                return True
        return False

    env = unittest.begin(ctx)

    version_scheme = Version.SCHEME.PGVER

    invalid_specs = [
        "",
        "!0.1",
        "<=16.3.0a",
        ">0.1.1.1",
        ">16.2.0",
        # Only a == or != clause may contain build-level metadata: ==16.2+b42
        # is valid, >=16.2+b42 isn’t.
        ">=16.2+b42",
    ]

    for expression in invalid_specs:
        res = Spec.new(expression, version_scheme = version_scheme, _fail = Mock.fail)
        asserts.true(env, is_error(res))

    return unittest.end(env)

invalid_spec_test = unittest.make(_invalid_spec_impl)

def _valid_spec_impl(ctx):
    env = unittest.begin(ctx)

    valid_specs = [
        ("*", ">=0.0"),
        ("==16.0", "==16.0"),
        ("=16.0", "==16.0"),
        ("16.0", "==16.0"),
        ("<=16.1", None),
        ("<16.1", "<16.1"),
        ("16", 'AllOf(Range(">=", "16.0"), Range("<", "17.0"))'),
        (">16rc1", None),
        (">=16rc1", None),
        ("==16.2+b42-12.2012-01-01.12h23", None),
        ("!=16rc1+build.2012-01-01.11h34", None),
        ("^16.2", 'AllOf(Range(">=", "16.2"), Range("<", "17.0"))'),
        ("~16.2", 'AllOf(Range(">=", "16.2"), Range("<", "16.3"))'),
        ("~=16.2", 'AllOf(Range(">=", "16.2"), Range("<", "16.3"))'),
        (">16.0,<=16.4", 'AllOf(Range(">", "16.0"), Range("<=", "16.4"))'),
    ]

    valid_specs_whitespace = [
        (" *  ", ">=0.0"),
        ("== 16.0", "==16.0"),
        ("= 16.0", "==16.0"),
        ("< 16.0 ", "<16.0"),
        ("== 16.2+b42 ", "==16.2+b42"),
        (">16.0, <=16.4", 'AllOf(Range(">", "16.0"), Range("<=", "16.4"))'),
    ]

    valid_specs += valid_specs_whitespace

    version_scheme = Version.SCHEME.PGVER
    for expression, clause in valid_specs:
        spec = Spec.new(expression, version_scheme = version_scheme)
        asserts.equals(env, expression.replace(" ", ""), spec.to_str())
        asserts.equals(env, clause or spec.to_str(), spec.clause.to_str())

    return unittest.end(env)

valid_spec_test = unittest.make(_valid_spec_impl)

def _match_spec_impl(ctx):
    env = unittest.begin(ctx)

    examples = dict([])

    # examples = { expression: ([match = True], [match = False]) }
    examples = dict([
        ("*", (
            [
                "16rc1",
                "16rc1+b42",
                "16.0",
                "16.0+b42",
                "16.1",
                "17.0",
            ],
            [],
        )),
    ])

    # Equality clauses
    examples |= dict([
        # A clause of ==16.2 will match version 16.2 and any version
        # differing only through its build number (16.2+b42 examples)
        ("%s16.2" % op, (
            [
                "16.2",
                "16.2+b42",
            ],
            [
                "16rc1",
                "16.3",
            ],
        ))
        for op in SimpleParser.OP_ALIASES
    ]) | dict([
        # A clause of ==16.1+b42 will only match that specific version:
        # 16.1+b43 and 16.1 are excluded
        ("==16.1+b42", (
            [
                "16.1+b42",
            ],
            [
                "16.1",
                "16.1+b43",
                "16.2",
            ],
        )),
        # A clause of ==16.1+ will only match that specific version: 16.1+b42
        # is excluded
        ("==16.1+", (
            [
                "16.1",
            ],
            [
                "16.1+b42",
                "16.2",
            ],
        )),
        # A clause of !=16.0 will prevent all versions with the same
        # major/minor combination: 16rc1 and 16.0+b42 are excluded’
        ("!=16.0", (
            [
                "16.1",
            ],
            [
                "16rc1",
                "16.0",
                "16.0+b42",
            ],
        )),
        # A clause of !=16.0- will only prevent build variations of that
        # version: 16rc1 is included, but not 16.0+b42
        ("!=16.0-", (
            [
                "16.1",
                "16rc1",
            ],
            [
                "16.0",
                "16.0+b42",
            ],
        )),
        # A clause of !=16.0+ will exclude only that exact version: 16rc1
        # and 16.0+b42 are included
        ("!=16.0+", (
            [
                "16rc1",
                "16.0+b42",
            ],
            [
                "16.0",
            ],
        )),
        ("!=16.0+b42", (
            [
                "16rc1",
                "16rc1+b42",
                "16.0",
                "16.0+b43",
            ],
            [
                "16.0+b42",
            ],
        )),
    ])

    # Comparison clauses
    examples |= dict([
        # A clause of <16.1 will match versions strictly below 16.1
        ("<16.1", (
            [
                "15.1",
                "16rc1",
                "16.0",
            ],
            [
                "16.1",
                "16.1+b42",
            ],
        )),
        # A clause of <16 will match versions strictly below 16.0
        ("<16", (
            [
                "15.1",
                "16rc1",
            ],
            [
                "16.0",
                "16.0+b42",
            ],
        )),
        # A clause of <16- will match versions strictly below 16.0,
        # including prereleases of 16.0: 16rc.1 is included
        ("<16-", (
            [
                "15.1",
                "16rc1",
            ],
            [
                "16.0",
                "16.0+b42",
            ],
        )),
        # A clause of <16rc3 will match versions strictly below
        # 16rc3, including prereleases: 16rc2 is included
        ("<16rc3", (
            [
                "16rc2",
            ],
            [
                "16rc3",
                "16.0",
                "16.0+b42",
            ],
        )),
        # A clause of <=XXX will match versions that match <XXX or ==XXX
        ("<=16.1", (
            [
                "15.1",
                "16rc1",
                "16.1",
                "16.1+b42",
            ],
            [
                "16.2",
            ],
        )),
        # A clause of >16.1 will match versions strictly above 16.1
        (">16.1", (
            [
                "16.2",
                "17rc1",
                "17.0",
            ],
            [
                "16.1",
                "16.1+b42",
            ],
        )),
        # A clause of >16 will match versions strictly above 16.0,
        # including all prereleases of 16.0
        (">16", (
            [
                "17.0",
            ],
            [
                "16rc1",
                "16.0",
                "16.0+b42",
                "16.1",
            ],
        )),
        # A clause of >16rc3 will match versions strictly above 16rc3,
        # including matching prereleases of 16.0: 16rc4 is included
        (">16rc3", (
            [
                "16rc4",
                "16.0",
                "16.0+b42",
                "16.1",
                "17.0",
            ],
            [
                "16rc3",
            ],
        )),
        # A clause of >=XXX will match versions that match >XXX or ==XXX
        (">=16.1", (
            [
                "16.1",
                "16.1+b42",
                "16.2",
                "17.0",
            ],
            [
                "16rc1",
                "16.0",
            ],
        )),
    ])

    # Extensions
    examples |= dict([
        ("^16.1", (
            [
                "16.1",
                "16.1+b42",
                "16.2",
                "16.3",
            ],
            [
                "15.0",
                "16.0",
                "17.0",
            ],
        )),
        ("~16.1", (
            [
                "16.1",
                "16.1+b42",
            ],
            [
                "15.0",
                "16.0",
                "16.2",
                "17.0",
            ],
        )),
        ("~=16.1", (
            [
                "16.1",
                "16.1+b42",
            ],
            [
                "15.0",
                "16.0",
                "16.2",
                "17.0",
            ],
        )),
        ("~=16", (
            [
                "16.0",
                "16.1",
                "16.1+b42",
                "16.2",
            ],
            [
                "15.0",
                "16rc1",
                "17rc1",
                "17.0",
            ],
        )),
    ])

    version_scheme = Version.SCHEME.PGVER

    for expression, cases in examples.items():
        match, nomatch = cases

        spec = Spec.new(expression, version_scheme = version_scheme)

        for version in match:
            asserts.true(env, spec.match(version))

        for version in nomatch:
            asserts.false(env, spec.match(version))

    return unittest.end(env)

match_spec_test = unittest.make(_match_spec_impl)

def _prerelease_check_impl(ctx):
    env = unittest.begin(ctx)

    version_scheme = Version.SCHEME.PGVER

    strict_spec = Spec.new(">=16.1-", version_scheme = version_scheme)
    lax_spec = Spec.new(">=16.1", version_scheme = version_scheme)

    versions = [
        "16rc1",
        "16.0",
    ]

    for version in versions:
        asserts.false(env, strict_spec.match(version))
        asserts.false(env, lax_spec.match(version))

    versions = [
        "16.1",
        "16.2",
        "17rc1",
        "17.0",
    ]

    for version in versions:
        asserts.true(env, strict_spec.match(version))
        asserts.true(env, lax_spec.match(version))

    return unittest.end(env)

prerelease_check_test = unittest.make(_prerelease_check_impl)

def _build_check_impl(ctx):
    env = unittest.begin(ctx)

    version_scheme = Version.SCHEME.PGVER

    spec = Spec.new("<=16rc1", version_scheme = version_scheme)
    version = "16rc1+4.2"

    asserts.true(env, spec.match(version))

    return unittest.end(env)

build_check_test = unittest.make(_build_check_impl)

TEST_SUITE_NAME = "spec_simple/pgver"

TEST_SUITE_TESTS = dict(
    invalid_spec = invalid_spec_test,
    valid_spec = valid_spec_test,
    match_spec = match_spec_test,
    prerelease_check = prerelease_check_test,
    build_check = build_check_test,
)

test_suite = lambda: _test_suite(TEST_SUITE_NAME, TEST_SUITE_TESTS)
