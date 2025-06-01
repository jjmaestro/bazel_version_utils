"""
spec/simple.bzl unit tests for PgVer

Mirrors tests/spec/spec_simple.bzl for PgVer versions
"""

load("@bazel_skylib//lib:unittest.bzl", "asserts", "unittest")
load("//spec:spec.bzl", Spec = "spec")

# buildifier: disable=bzl-visibility
load("//spec/internal:simple.bzl", SimpleParser = "simpleparser")
load("//tests:mock.bzl", Mock = "mock")
load("//tests:suite.bzl", _test_suite = "test_suite")
load("//version:versions.bzl", Versions = "versions")

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

    cls_name = Versions.VERSIONS.PGVER

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
        res = Spec.new(expression, cls_name = cls_name, _fail = Mock.fail)
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
        ("== 16rc1 ", "==16rc1"),
        (">16.0, <=16.4", 'AllOf(Range(">", "16.0"), Range("<=", "16.4"))'),
    ]

    valid_specs += valid_specs_whitespace

    cls_name = Versions.VERSIONS.PGVER
    for expression, clause in valid_specs:
        spec = Spec.new(expression, cls_name = cls_name)
        asserts.equals(env, expression.replace(" ", ""), spec.to_str())
        asserts.equals(env, clause or spec.to_str(), spec.clause.to_str())

    return unittest.end(env)

valid_spec_test = unittest.make(_valid_spec_impl)

def _foo_impl(ctx):
    env = unittest.begin(ctx)

    expression = "==16.2.0+b41"
    version = "16.2.0"
    spec = Spec.new(expression)
    asserts.false(env, spec.match(version))

    expression = "==16.2+b42"
    version = "16.2"
    cls_name = Versions.VERSIONS.PGVER
    spec = Spec.new(expression, cls_name = cls_name)
    asserts.false(env, spec.match(version))

    return unittest.end(env)

foo_test = unittest.make(_foo_impl)

def _match_spec_impl(ctx):
    env = unittest.begin(ctx)

    # examples = { expression: ([match = True], [match = False]) }
    examples = dict([
        ("*", (
            ["16.2", "17rc1"],
            [],
        )),
    ])

    examples |= dict([
        ("%s16.2" % op, (
            ["16.2"],
            ["16.3"],
        ))
        for op in SimpleParser.OP_ALIASES
    ]) | dict([
        ("<=16.0", (
            ["16.0", "16rc1"],
            [],
        )),
        ("!=16.2-", (
            ["16.0", "16rc1"],
            ["16.2"],
        )),
        ("!=16-", (
            ["15.0", "17.0"],
            ["16.0", "16.2", "16rc1"],
        )),
        (">=16.2", (
            ["16.2", "17rc1", "17.0"],
            ["16.1"],
        )),
        (">16.2", (
            ["17rc1", "17.0"],
            [],
        )),
        ("<17-", (
            ["16.4", "17alpha1", "17rc4"],
            ["17.0"],
        )),
        ("^16.2", (
            ["16.2", "16.3"],
            ["16.1"],
        )),
        ("~16.2", (
            ["16.2"],
            ["16.1", "16.3"],
        )),
        ("~=16.2", (
            ["16.2"],
            ["16.1", "16.3"],
        )),
        ("~=16", (
            ["16.0", "16.2"],
            ["15.1", "17.2"],
        )),
    ])

    cls_name = Versions.VERSIONS.PGVER

    for expression, cases in examples.items():
        match, nomatch = cases

        spec = Spec.new(expression, cls_name = cls_name)

        for version in match:
            asserts.true(env, spec.match(version))

        for version in nomatch:
            asserts.false(env, spec.match(version))

    return unittest.end(env)

match_spec_test = unittest.make(_match_spec_impl)

def _match2_spec_impl(ctx):
    env = unittest.begin(ctx)

    # examples = { expression: ([match = True], [match = False]) }
    examples = dict([
        ("*", (
            [
                "16.1.0-rc1",
                "16.1.0-rc1+b42",
                "16.1.0",
                "16.1.0+b42",
                "16.2.0",
                "17.0.0",
            ],
            [],
        )),
    ])

    # Equality clauses
    examples |= dict([
        # A clause of ==16.1.0 will match version 16.1.0 and any version
        # differing only through its build number (16.1.0+b42 examples)
        ("%s16.1.0" % op, (
            [
                "16.1.0",
                "16.1.0+b42",
            ],
            [
                "16.1.0-rc1",
                "16.2.0",
            ],
        ))
        for op in SimpleParser.OP_ALIASES
    ]) | dict([
        # A clause of ==16.1.0+b42 will only match that specific version:
        # 16.1.0+b43 and 16.1.0 are excluded
        ("==16.1.0+b42", (
            [
                "16.1.0+b42",
            ],
            [
                "16.1.0-rc1",
                "16.1.0",
                "16.1.0+b43",
                "16.2.0",
            ],
        )),
        # A clause of ==16.1.0+ will only match that specific version: 16.1.0+b42
        # is excluded
        ("==16.1.0+", (
            [
                "16.1.0",
            ],
            [
                "16.1.0-rc1",
                "16.1.0+b42",
                "16.2.0",
            ],
        )),
        # A clause of !=16.1.0 will prevent all versions with the same
        # major/minor/patch combination: 16.1.0-rc.1 and 16.1.0+b42 are excluded’
        ("!=16.1.0", (
            [
                "16.2.0",
            ],
            [
                "16.1.0-rc1",
                "16.1.0",
                "16.1.0+b42",
            ],
        )),
        # A clause of !=16.1.0- will only prevent build variations of that
        # version: 16.1.0-rc.1 is included, but not 16.1.0+b42
        ("!=16.1.0-", (
            [
                "0.1.1",
                "16.1.0-rc1",
            ],
            [
                "16.1.0",
                "16.1.0+b42",
            ],
        )),
        # A clause of !=16.1.0+ will exclude only that exact version: 16.1.0-rc.1
        # and 16.1.0+b42 are included
        ("!=16.1.0+", (
            [
                "16.1.0-rc1",
                "16.1.0+b42",
            ],
            [
                "16.1.0",
            ],
        )),
        ("!=16.1.0+b42", (
            [
                "0.1.1",
                "0.1.1+b42",
                "16.1.0",
                "16.1.0-rc1",
                "16.1.0-rc1+b42",
                "16.1.0+b43",
            ],
            [
                "16.1.0+b42",
            ],
        )),
    ])

    # Comparison clauses
    examples |= dict([
        # A clause of <16.1.0 will match versions strictly below 16.1.0,
        # excluding prereleases of 16.1.0: 16.1.0-rc.1 is excluded
        ("<16.1.0", (
            [
                "0.1.1",
                "16.1.0-rc1",
            ],
            [
                "16.1.0",
                "16.1.0+b42",
            ],
        )),
        # A clause of <16.1.0- will match versions strictly below 16.1.0,
        # including prereleases of 16.1.0: 16.1.0-rc.1 is included
        ("<16.1.0-", (
            [
                "0.1.1",
                "16.1.0-rc1",
            ],
            [
                "16.1.0",
                "16.1.0+b42",
            ],
        )),
        # A clause of <16.1.0-rc.3 will match versions strictly below
        # 16.1.0-rc.3, including prereleases: 16.1.0-rc.2 is included
        ("<16.1.0-rc3", (
            [
                "16.1.0-rc2",
            ],
            [
                "16.1.0-rc4",
                "16.1.0",
                "16.1.0+b42",
            ],
        )),
        # A clause of <=XXX will match versions that match <XXX or ==XXX
        ("<=16.1.0", (
            [
                "0.1.1",
                "16.1.0-rc1",
                "16.1.0",
                "16.1.0+b42",
            ],
            [
                "16.2.0",
            ],
        )),

        # A clause of >16.1.0 will match versions strictly above 16.1.0,
        # including all prereleases of 16.2.0
        (">16.1.0", (
            [
                "16.2.0-rc1",
                "16.2.0",
                "16.2.0+b42",
                "0.2.0",
                "1.0.0",
            ],
            [
                "16.1.0-rc1",
                "16.1.0",
                "16.1.0+b42",
            ],
        )),
        # A clause of >16.1.0-rc.3 will match versions strictly above
        # 16.1.0-rc.3, including matching prereleases of 16.1.0: 16.1.0-rc4 is
        # included
        (">16.1.0-rc3", (
            [
                "16.1.0-rc4",
                "16.1.0",
                "16.1.0+b42",
                "0.2.0",
                "1.0.0",
            ],
            [
                "16.1.0-rc3",
            ],
        )),
        # A clause of >=XXX will match versions that match >XXX or ==XXX
        (">=16.1.0", (
            [
                "16.1.0",
                "16.1.0+b42",
                "0.2.0",
                "1.0.0",
            ],
            [
                "16.1.0-rc1",
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
                "17rc1",
            ],
            [
                "15.0",
                "17.0",
            ],
        )),
        ("~16.1", (
            [
                "16.1",
                "16.1+b42",
                "16.2",
                "16.3",
                "17rc1",
            ],
            [
                "15.0",
                "17.0",
            ],
        )),
        ("~=16.1", (
            [
                "16.1",
                "16.1+b42",
                "16.2",
                "16.3",
                "17rc1",
            ],
            [
                "15.0",
                "17.0",
            ],
        )),
        ("~=16", (
            [
                "16.1",
                "16.1+b42",
                "16.2",
                "16.3",
                "17rc1",
            ],
            [
                "15.0",
                "17.0",
            ],
        )),
    ])

    for expression, cases in examples.items():
        match, nomatch = cases

        spec = Spec.new(expression)

        for version in match:
            asserts.true(env, spec.match(version))

        for version in nomatch:
            asserts.false(env, spec.match(version))

    return unittest.end(env)

match2_spec_test = unittest.make(_match2_spec_impl)

def _prerelease_check_impl(ctx):
    env = unittest.begin(ctx)

    cls_name = Versions.VERSIONS.PGVER

    strict_spec = Spec.new(">=16.1-", cls_name = cls_name)
    lax_spec = Spec.new(">=16.1", cls_name = cls_name)

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

TEST_SUITE_NAME = "spec_simple/pgver"

TEST_SUITE_TESTS = dict(
    invalid_spec = invalid_spec_test,
    valid_spec = valid_spec_test,
    match_spec = match_spec_test,
    prerelease_check = prerelease_check_test,
    foo = foo_test,
)

test_suite = lambda: _test_suite(TEST_SUITE_NAME, TEST_SUITE_TESTS)
