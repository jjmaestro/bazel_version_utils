"""unit tests mirroring python-semanticversion/tests/test_parsing.py"""

load("@bazel_skylib//lib:unittest.bzl", "asserts", "unittest")
load("//tests:mock.bzl", Mock = "mock")
load("//tests:suite.bzl", _test_suite = "test_suite")
load("//version:semver.bzl", SemVer = "semver")

def _parsing_invalid_impl(ctx):
    def is_error(res):
        errors = (
            "Invalid version string",
            "Empty version string",
            "Invalid semantic version",
        )

        for error in errors:
            if res.startswith(error):
                return True
        return False

    env = unittest.begin(ctx)

    invalid_versions = [
        None,
        "",
        "0",
        "0.1",
        "0.1.4a",
        "0.1.1.1",
        "0.1.2-rc23,1",
    ]

    for version in invalid_versions:
        res = SemVer.parse(version, _fail = Mock.fail)
        asserts.true(env, is_error(res))

    return unittest.end(env)

parsing_invalid_test = unittest.make(_parsing_invalid_impl)

def _parsing_valid_impl(ctx):
    env = unittest.begin(ctx)

    valid_versions = [
        "0.1.1",
        "0.1.2-rc1",
        "0.1.2-rc1.3.4",
        "0.1.2+build42-12.2012-01-01.12h23",
        "0.1.2-rc1.3-14.15+build.2012-01-01.11h34",
    ]

    for version in valid_versions:
        sv = SemVer.parse(version)
        asserts.equals(env, version, sv.to_str())

    return unittest.end(env)

parsing_valid_test = unittest.make(_parsing_valid_impl)

def _valid_fields_impl(ctx):
    env = unittest.begin(ctx)

    valid_fields = [
        ("0.1.1", [0, 1, 1, (), ()]),
        ("0.1.2-rc1", [0, 1, 2, ("rc1",), ()]),
        ("0.1.2-rc1.3.4", [0, 1, 2, ("rc1", "3", "4"), ()]),
        (
            "0.1.2+build42-12.2012-01-01.12h23",
            (0, 1, 2, (), ("build42-12", "2012-01-01", "12h23")),
        ),
        (
            "0.1.2-rc1.3-14.15+build.2012-01-01.11h34",
            (0, 1, 2, ("rc1", "3-14", "15"), ("build", "2012-01-01", "11h34")),
        ),
    ]

    for version, fields in valid_fields:
        sv = SemVer.new(*fields)
        asserts.equals(env, version, sv.to_str())

    return unittest.end(env)

valid_fields_test = unittest.make(_valid_fields_impl)

TEST_SUITE_NAME = "semver_parsing"

TEST_SUITE_TESTS = dict(
    parsing_invalid = parsing_invalid_test,
    parsing_valid = parsing_valid_test,
    valid_fields = valid_fields_test,
)

test_suite = lambda: _test_suite(TEST_SUITE_NAME, TEST_SUITE_TESTS)
