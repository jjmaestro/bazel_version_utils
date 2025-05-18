"""unit tests mirroring python-semanticversion/tests/test_spec.py"""

load("@bazel_skylib//lib:unittest.bzl", "asserts", "unittest")
load("//tests:mock.bzl", Mock = "mock")
load("//tests:suite.bzl", _test_suite = "test_suite")
load("//version:semver.bzl", SemVer = "semver")

def _major_minor_patch_impl(ctx):
    env = unittest.begin(ctx)

    # SPEC:
    # A normal version number MUST take the form X.Y.Z

    res = SemVer.parse("1", _fail = Mock.fail)
    asserts.true(env, res.startswith("Invalid semantic version"))

    res = SemVer.parse("1.1", _fail = Mock.fail)
    asserts.true(env, res.startswith("Invalid semantic version"))

    # Doesn't raise
    SemVer.parse("1.2.3")

    res = SemVer.parse("1.2.3.4", _fail = Mock.fail)
    asserts.true(env, res.startswith("Invalid semantic version"))

    # SPEC:
    # Where X, Y, and Z are non-negative integers,

    res = SemVer.parse("1.2.A", _fail = Mock.fail)
    asserts.true(env, res.startswith("Invalid semantic version"))

    res = SemVer.parse("1.-2.3", _fail = Mock.fail)
    asserts.true(env, res.startswith("Invalid semantic version"))

    # Valid
    v = SemVer.parse("1.2.3")
    asserts.equals(env, 1, v.major)
    asserts.equals(env, 2, v.minor)
    asserts.equals(env, 3, v.patch)

    # SPEC:
    # And MUST NOT contain leading zeroes
    res = SemVer.parse("01.2.1", _fail = Mock.fail)
    asserts.true(env, res.startswith("Invalid semantic version major"))
    res = SemVer.parse("1.02.1", _fail = Mock.fail)
    asserts.true(env, res.startswith("Invalid semantic version minor/patch"))
    res = SemVer.parse("1.2.01", _fail = Mock.fail)
    asserts.true(env, res.startswith("Invalid semantic version minor/patch"))

    # Valid
    v = SemVer.parse("0.0.0")
    asserts.equals(env, 0, v.major)
    asserts.equals(env, 0, v.minor)
    asserts.equals(env, 0, v.patch)

    return unittest.end(env)

major_minor_patch_test = unittest.make(_major_minor_patch_impl)

def _prerelease_impl(ctx):
    env = unittest.begin(ctx)

    # SPEC:
    # A pre-release version MAY be denoted by appending a hyphen and a
    # series of dot separated identifiers immediately following the patch
    # version.
    res = SemVer.parse("1.2.3 -23", _fail = Mock.fail)
    asserts.true(env, res.startswith("Invalid semantic version"))

    # Valid
    v = SemVer.parse("1.2.3-23")
    asserts.equals(env, (23,), v.prerelease)

    # SPEC:
    # Identifiers MUST comprise only ASCII alphanumerics and hyphen.
    # Identifiers MUST NOT be empty
    res = SemVer.parse("1.2.3-a,", _fail = Mock.fail)
    asserts.true(env, res.startswith("Invalid semantic version"))

    res = SemVer.parse("1.2.3-..", _fail = Mock.fail)
    asserts.true(env, res.startswith("Invalid semantic version"))

    # SPEC:
    # Numeric identifiers MUST NOT include leading zeroes.
    res = SemVer.parse("11.2.3-a0.01", _fail = Mock.fail)
    asserts.true(env, res.startswith("Invalid semantic version"))

    res = SemVer.parse("11.2.3-00", _fail = Mock.fail)
    asserts.true(env, res.startswith("Invalid semantic version"))

    # Valid
    v = SemVer.parse("1.2.3-0a.0.000zz")
    asserts.equals(env, ("0a", 0, "000zz"), v.prerelease)

    return unittest.end(env)

prerelease_test = unittest.make(_prerelease_impl)

def _build_impl(ctx):
    env = unittest.begin(ctx)

    # SPEC:
    # Build metadata MAY be denoted by appending a plus sign and a series of
    # dot separated identifiers immediately following the patch or
    # pre-release version
    v = SemVer.parse("1.2.3")
    asserts.equals(env, (), v.build)

    res = SemVer.parse("1.2.3 +4", _fail = Mock.fail)
    asserts.true(env, res.startswith("Invalid semantic version"))

    # SPEC:
    # Identifiers MUST comprise only ASCII alphanumerics and hyphen.
    # Identifiers MUST NOT be empty
    res = SemVer.parse("1.2.3+a,", _fail = Mock.fail)
    asserts.true(env, res.startswith("Invalid semantic version"))
    res = SemVer.parse("1.2.3+..", _fail = Mock.fail)
    asserts.true(env, res.startswith("Invalid semantic version"))

    # SPEC:
    # Leading zeroes allowed in build metadata
    v = SemVer.parse("1.2.3+0.0a.01")
    asserts.equals(env, (0, "0a", 1), v.build)

    return unittest.end(env)

build_test = unittest.make(_build_impl)

def _precedence_impl(ctx):
    env = unittest.begin(ctx)

    # SPEC:
    # Precedence is determined by the first difference when comparing from
    # left to right as follows: Major, minor, and patch versions are always
    # compared numerically.
    # Example: 1.0.0 < 2.0.0 < 2.1.0 < 2.1.1
    versions = [
        "1.0.0",
        "2.0.0",
        "2.1.0",
        "2.1.1",
    ]
    for v1, v2 in zip(versions[:-1], versions[1:]):
        asserts.true(env, SemVer.parse(v1).lt(SemVer.parse(v2)))

    # SPEC:
    # When major, minor, and patch are equal, a pre-release version has
    # lower precedence than a normal version.
    # Example: 1.0.0-alpha < 1.0.0
    asserts.true(env, SemVer.parse("1.0.0-alpha").lt(SemVer.parse("1.0.0")))

    # SPEC:
    # Precedence for two pre-release versions with the same major, minor,
    # and patch version MUST be determined by comparing each dot separated
    # identifier from left to right until a difference is found as follows:
    # identifiers consisting of only digits are compared numerically
    asserts.true(env, SemVer.parse("1.0.0-1").lt(SemVer.parse("1.0.0-2")))

    # and identifiers with letters or hyphens are compared lexically in
    # ASCII sort order.
    asserts.true(env, SemVer.parse("1.0.0-aa").lt(SemVer.parse("1.0.0-ab")))

    # Numeric identifiers always have lower precedence than
    # non-numeric identifiers.
    asserts.true(env, SemVer.parse("1.0.0-9").lt(SemVer.parse("1.0.0-a")))

    # A larger set of pre-release fields has a higher precedence than a
    # smaller set, if all of the preceding identifiers are equal.
    asserts.true(env, SemVer.parse("1.0.0-a.b.c").lt(SemVer.parse("1.0.0-a.b.c.0")))

    # build is ignored when comparing
    asserts.true(env, SemVer.parse("1.0.0+b.1").eq(SemVer.parse("1.0.0+b.2")))
    asserts.false(env, SemVer.parse("1.0.0+b.1").lt(SemVer.parse("1.0.0+b.2")))
    asserts.true(env, SemVer.parse("1.0.0+b.2").eq(SemVer.parse("1.0.0")))
    asserts.false(env, SemVer.parse("1.0.0+b.2").lt(SemVer.parse("1.0.0")))

    # Example: 1.0.0-alpha < 1.0.0-alpha.1 < 1.0.0-alpha.beta
    # < 1.0.0-beta < 1.0.0-beta.2 < 1.0.0-beta.11 < 1.0.0-rc.1 < 1.0.0.
    versions = [
        "1.0.0-alpha",
        "1.0.0-alpha.1",
        "1.0.0-alpha.beta",
        "1.0.0-beta",
        "1.0.0-beta.2",
        "1.0.0-beta.11",
        "1.0.0-rc.1",
        "1.0.0",
    ]
    for v1, v2 in zip(versions[:-1], versions[1:]):
        asserts.true(env, SemVer.parse(v1).lt(SemVer.parse(v2)))

    return unittest.end(env)

precedence_test = unittest.make(_precedence_impl)

TEST_SUITE_NAME = "semver_specification"

TEST_SUITE_TESTS = dict(
    major_minor_patch = major_minor_patch_test,
    prerelease = prerelease_test,
    build = build_test,
    precedence = precedence_test,
)

test_suite = lambda: _test_suite(TEST_SUITE_NAME, TEST_SUITE_TESTS)
