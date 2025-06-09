"""
NPM spec equivalency with npm_server tests

See:
https://github.com/rbarrois/python-semanticversion/issues/100
https://github.com/rbarrois/python-semanticversion/pull/101
https://github.com/rbarrois/python-semanticversion/issues/115
https://github.com/rbarrois/python-semanticversion/pull/116
"""

load("@bazel_skylib//lib:unittest.bzl", "asserts", "unittest")
load("//spec:spec.bzl", Spec = "spec")
load("//tests:suite.bzl", _test_suite = "test_suite")

def _npm_server_impl(ctx):
    env = unittest.begin(ctx)

    # NOTE:
    # The value in "satisfies" is what npm-server returns when matching the
    # version so we should match that result.
    params = [
        ("1.0.0", "1.0.0", True),
        ("2.0.0", "1.0.0", False),
        ("1.0.0", "2.0.0", False),
        ("1.2.0", "<1.5.0 >1.0.0 || >1.5.0 <2.0.0", True),
        ("2.0.0", "<1.5.0 >1.0.0 || >1.5.0 <2.0.0", False),
        ("1.5.0", "<1.5.0 >1.0.0 || >1.5.0 <2.0.0", False),
        ("1.0.0-100", "1.0.0-100", True),
        ("1.0.0-200", "1.0.0-100", False),
        ("1.0.0+100", "1.0.0+100", True),
        ("1.0.0-200", "<1.0.0-150 >=1.0.0-100 || >1.0.0-150 <1.0.0-200", False),
        ("1.0.0-150", "<1.0.0-150 >=1.0.0-100 || >1.0.0-150 <1.0.0-200", False),
        ("1.0.0", "1.0.0-alpha.1", False),
        ("1.0.0-rc1", ">=1.0.0-", False),
        ("1.0.0-rc1", ">=1.0.0-1", True),
        ("1.0.0", "1.0.0-100", False),
        ("1.0.0-100", "<1.0.0-150", True),
        ("1.0.0-100", "<1.0.0-150 >=1.0.0-100 || >1.0.0-150 <1.0.0-200", True),
        ("1.0.0-199", "<1.0.0-150 >=1.0.0-100 || >1.0.0-150 <1.0.0-200", True),
        ("1.0.0+200", "1.0.0+100", True),
        ("1.0.0", "1.0.0+100", True),
        ("1.0.0+100", "<1.0.0+150 >=1.0.0+100 || >1.0.0+150 <1.0.0+200", False),
        ("1.0.0+199", "<1.0.0+150 >=1.0.0+100 || >1.0.0+150 <1.0.0+200", False),
        ("1.0.0+200", "<1.0.0+150 >=1.0.0+100 || >1.0.0+150 <1.0.0+200", False),
        ("1.0.0+150", "<1.0.0+150 >=1.0.0+100 || >1.0.0+150 <1.0.0+200", False),
    ]

    for version, spec, satisfies in params:
        s = Spec.new(spec, syntax = Spec.SYNTAX.NPM)

        if satisfies:
            asserts.true(env, s.match(version))
        else:
            asserts.false(env, s.match(version))

    return unittest.end(env)

npm_server_test = unittest.make(_npm_server_impl)

TEST_SUITE_NAME = "npm_server"

TEST_SUITE_TESTS = dict(
    npm_server = npm_server_test,
)

test_suite = lambda: _test_suite(TEST_SUITE_NAME, TEST_SUITE_TESTS)
