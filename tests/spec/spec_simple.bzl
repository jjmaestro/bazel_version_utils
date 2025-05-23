"""
spec/simple.bzl unit tests for SemVer

Mirrors python-semanticversion/tests/test_match.py and adds more tests from the
[`SimpleSpec` Reference docs].

[`SimpleSpec` Reference docs]: https://python-semanticversion.readthedocs.io/en/latest/reference.html#semantic_version.SimpleSpec
"""

load("@bazel_skylib//lib:unittest.bzl", "asserts", "unittest")
load("//spec:spec.bzl", Spec = "spec")

# buildifier: disable=bzl-visibility
load("//spec/internal:simple.bzl", SimpleParser = "simpleparser")
load("//tests:mock.bzl", Mock = "mock")
load("//tests:suite.bzl", _test_suite = "test_suite")

def _invalid_spec_impl(ctx):
    def is_error(res):
        errors = (
            "Empty spec",
            "Can't find a valid spec operator",
            "Invalid spec expression",
            "Invalid semantic version",
        )

        for error in errors:
            if res.startswith(error):
                return True
        return False

    env = unittest.begin(ctx)

    invalid_specs = [
        "",
        "!0.1",
        "<=0.1.4a",
        ">0.1.1.1",
        # Only a == or != clause may contain build-level metadata: ==1.2.3+b42
        # is valid, >=1.2.3+b42 isn’t.
        ">=1.2.3+b42",
        "<0.1.2-rc1.3-14.15+build.2012-01-01.11h34",
        "< = 1.0.0",
    ]

    for expression in invalid_specs:
        res = Spec.new(expression, _fail = Mock.fail)
        asserts.true(env, is_error(res))

    return unittest.end(env)

invalid_spec_test = unittest.make(_invalid_spec_impl)

def _valid_spec_impl(ctx):
    env = unittest.begin(ctx)

    valid_specs = [
        ("*", ">=0.0.0"),
        ("==0.1.0", "==0.1.0"),
        ("=0.1.0", "==0.1.0"),
        ("0.1.0", "==0.1.0"),
        ("<=0.1.1", None),
        ("<0.1", "<0.1.0"),
        ("1", 'AllOf(Range(">=", "1.0.0"), Range("<", "2.0.0"))'),
        (">0.1.2-rc1", None),
        (">=0.1.2-rc1.3.4", None),
        ("==0.1.2+b42-12.2012-01-01.12h23", None),
        ("!=0.1.2-rc1.3-14.15+build.2012-01-01.11h34", None),
        ("^0.1.2", 'AllOf(Range(">=", "0.1.2"), Range("<", "0.2.0"))'),
        ("~0.1.2", 'AllOf(Range(">=", "0.1.2"), Range("<", "0.2.0"))'),
        ("~=0.1.2", 'AllOf(Range(">=", "0.1.2"), Range("<", "0.2.0"))'),
        (">0.1.0,<=0.1.5", 'AllOf(Range(">", "0.1.0"), Range("<=", "0.1.5"))'),
    ]

    valid_specs_whitespace = [
        (" *  ", ">=0.0.0"),
        ("== 0.1.0", "==0.1.0"),
        ("= 0.1.0", "==0.1.0"),
        ("< 0.1 ", "<0.1.0"),
        ("== 0.1.2+b42 ", "==0.1.2+b42"),
        (">0.1.0, <=0.1.5", 'AllOf(Range(">", "0.1.0"), Range("<=", "0.1.5"))'),
    ]

    valid_specs += valid_specs_whitespace

    for expression, clause in valid_specs:
        spec = Spec.new(expression)
        asserts.equals(env, expression.replace(" ", ""), spec.to_str())
        asserts.equals(env, clause or spec.to_str(), spec.clause.to_str())

    return unittest.end(env)

valid_spec_test = unittest.make(_valid_spec_impl)

def _match_spec_impl(ctx):
    env = unittest.begin(ctx)

    # examples = { expression: ([match = True], [match = False]) }
    examples = dict([
        ("*", (
            [
                "0.1.1",
                "0.1.1+b4.5",
                "0.1.2-rc1",
                "0.1.2-rc1.3",
                "0.1.2-rc1.3.4",
                "0.1.2+b42-12.2012-01-01.12h23",
                "0.1.2-rc1.3-14.15+build.2012-01-01.11h34",
                "0.2.0",
                "1.0.0",
            ],
            [],
        )),
    ])

    # Equality clauses
    examples |= dict([
        # A clause of ==0.1.2 will match version 0.1.2 and any version
        # differing only through its build number (0.1.2+b42 examples)
        ("%s0.1.2" % op, (
            [
                "0.1.2",
                "0.1.2+b42",
            ],
            [
                "0.1.2-rc1",
                "0.1.3",
            ],
        ))
        for op in SimpleParser.OP_ALIASES
    ]) | dict([
        # A clause of ==0.1.2+b42 will only match that specific version:
        # 0.1.2+b43 and 0.1.2 are excluded
        ("==0.1.2+b42", (
            [
                "0.1.2+b42",
            ],
            [
                "0.1.2-rc1",
                "0.1.2",
                "0.1.2+b43",
                "0.1.3",
            ],
        )),
        # A clause of ==0.1.2+ will only match that specific version: 0.1.2+b42
        # is excluded
        ("==0.1.2+", (
            [
                "0.1.2",
            ],
            [
                "0.1.2-rc1",
                "0.1.2+b42",
                "0.1.3",
            ],
        )),
        # A clause of !=0.1.2 will prevent all versions with the same
        # major/minor/patch combination: 0.1.2-rc.1 and 0.1.2+b42 are excluded’
        ("!=0.1.2", (
            [
                "0.1.3",
            ],
            [
                "0.1.2-rc1",
                "0.1.2",
                "0.1.2+b42",
            ],
        )),
        # A clause of !=0.1.2- will only prevent build variations of that
        # version: 0.1.2-rc.1 is included, but not 0.1.2+b42
        ("!=0.1.2-", (
            [
                "0.1.1",
                "0.1.2-rc1",
            ],
            [
                "0.1.2",
                "0.1.2+b42",
            ],
        )),
        # A clause of !=0.1.2+ will exclude only that exact version: 0.1.2-rc.1
        # and 0.1.2+b42 are included
        ("!=0.1.2+", (
            [
                "0.1.2-rc1",
                "0.1.2+b42",
            ],
            [
                "0.1.2",
            ],
        )),
        ("!=0.1.2+b42", (
            [
                "0.1.1",
                "0.1.1+b42",
                "0.1.2",
                "0.1.2-rc1",
                "0.1.2-rc1+b42",
                "0.1.2+b43",
            ],
            [
                "0.1.2+b42",
            ],
        )),
    ])

    # Comparison clauses
    examples |= dict([
        # A clause of <0.1.2 will match versions strictly below 0.1.2,
        # excluding prereleases of 0.1.2: 0.1.2-rc.1 is excluded
        ("<0.1.2", (
            [
                "0.1.1",
                "0.1.2-rc1",
            ],
            [
                "0.1.2",
                "0.1.2+b42",
            ],
        )),
        # A clause of <0.1.2- will match versions strictly below 0.1.2,
        # including prereleases of 0.1.2: 0.1.2-rc.1 is included
        ("<0.1.2-", (
            [
                "0.1.1",
                "0.1.2-rc1",
            ],
            [
                "0.1.2",
                "0.1.2+b42",
            ],
        )),
        # A clause of <0.1.2-rc.3 will match versions strictly below
        # 0.1.2-rc.3, including prereleases: 0.1.2-rc.2 is included
        ("<0.1.2-rc3", (
            [
                "0.1.2-rc2",
            ],
            [
                "0.1.2-rc4",
                "0.1.2",
                "0.1.2+b42",
            ],
        )),
        # A clause of <=XXX will match versions that match <XXX or ==XXX
        ("<=0.1.2", (
            [
                "0.1.1",
                "0.1.2-rc1",
                "0.1.2",
                "0.1.2+b42",
            ],
            [
                "0.1.3",
            ],
        )),

        # A clause of >0.1.2 will match versions strictly above 0.1.2,
        # including all prereleases of 0.1.3
        (">0.1.2", (
            [
                "0.1.3-rc1",
                "0.1.3",
                "0.1.3+b42",
                "0.2.0",
                "1.0.0",
            ],
            [
                "0.1.2-rc1",
                "0.1.2",
                "0.1.2+b42",
            ],
        )),
        # A clause of >0.1.2-rc.3 will match versions strictly above
        # 0.1.2-rc.3, including matching prereleases of 0.1.2: 0.1.2-rc4 is
        # included
        (">0.1.2-rc3", (
            [
                "0.1.2-rc4",
                "0.1.2",
                "0.1.2+b42",
                "0.2.0",
                "1.0.0",
            ],
            [
                "0.1.2-rc3",
            ],
        )),
        # A clause of >=XXX will match versions that match >XXX or ==XXX
        (">=0.1.2", (
            [
                "0.1.2",
                "0.1.2+b42",
                "0.2.0",
                "1.0.0",
            ],
            [
                "0.1.2-rc1",
            ],
        )),
    ])

    # Extensions
    examples |= dict([
        ("^0.1.2", (
            [
                "0.1.2",
                "0.1.2+bd42",
                "0.1.3-rc1",
                "0.1.3",
                "0.1.4",
            ],
            [
                "0.2.0",
                "1.0.0",
            ],
        )),
        ("~0.1.2", (
            [
                "0.1.2",
                "0.1.2+b42",
                "0.1.3-rc1",
                "0.1.3",
                "0.1.4",
            ],
            [
                "0.2.0",
                "1.0.0",
            ],
        )),
        ("~=1.4.5", (
            [
                "1.4.5",
                "1.4.10-rc1",
                "1.4.10",
            ],
            [
                "1.5.0",
            ],
        )),
        ("~=1.4", (
            [
                "1.4.0",
                "1.6.10-rc1",
                "1.6.10",
            ],
            [
                "2.0.0",
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

match_spec_test = unittest.make(_match_spec_impl)

def _prerelease_check_impl(ctx):
    env = unittest.begin(ctx)

    strict_spec = Spec.new(">=0.1.1-")
    lax_spec = Spec.new(">=0.1.1")

    versions = [
        "0.1.1-rc1",
        "0.1.1-rc1+4.2",
        "0.1.0",
    ]

    for version in versions:
        asserts.false(env, strict_spec.match(version))
        asserts.false(env, lax_spec.match(version))

    versions = [
        "0.2.0-rc1",
        "0.2.0",
        "1.0.0",
    ]

    for version in versions:
        asserts.true(env, strict_spec.match(version))
        asserts.true(env, lax_spec.match(version))

    return unittest.end(env)

prerelease_check_test = unittest.make(_prerelease_check_impl)

def _build_check_impl(ctx):
    env = unittest.begin(ctx)

    spec = Spec.new("<=0.1.1-rc1")
    version = "0.1.1-rc1+4.2"

    asserts.true(env, spec.match(version))

    return unittest.end(env)

build_check_test = unittest.make(_build_check_impl)

TEST_SUITE_NAME = "spec_simple"

TEST_SUITE_TESTS = dict(
    invalid_spec = invalid_spec_test,
    valid_spec = valid_spec_test,
    match_spec = match_spec_test,
    prerelease_check = prerelease_check_test,
    build_check = build_check_test,
)

test_suite = lambda: _test_suite(TEST_SUITE_NAME, TEST_SUITE_TESTS)
