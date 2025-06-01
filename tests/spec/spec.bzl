"""
spec/spec.bzl unit tests
"""

load("@bazel_skylib//lib:unittest.bzl", "asserts", "unittest")
load("//spec:spec.bzl", Spec = "spec")
load("//tests:mock.bzl", Mock = "mock")
load("//tests:suite.bzl", _test_suite = "test_suite")
load("//version:version.bzl", Version = "version")

def _invalid_impl(ctx):
    env = unittest.begin(ctx)

    expression = "_1.2.3"

    res = Spec.new(expression, syntax = "foo", _fail = Mock.fail)
    asserts.true(env, res.startswith("Unknown syntax"))

    res = Spec.new(expression, syntax = "foo", _fail = Mock.fail)
    asserts.true(env, res.startswith("Unknown syntax"))

    return unittest.end(env)

invalid_test = unittest.make(_invalid_impl)

def _simple_impl(ctx):
    env = unittest.begin(ctx)

    syntax = Spec.SYNTAX.SIMPLE

    expression = "<1.2.3"
    spec = Spec.new(expression)

    asserts.equals(env, syntax, spec.syntax)
    asserts.equals(env, expression, spec.expression)
    asserts.equals(env, expression, spec.clause.to_str())

    expression = ">=1.2.3,<=1.2.5"
    spec = Spec.new(expression)

    asserts.equals(env, syntax, spec.syntax)
    asserts.equals(env, expression.replace(" ", ""), spec.expression)
    expected = 'AllOf(Range(">=", "1.2.3"), Range("<=", "1.2.5"))'
    asserts.equals(env, expected, spec.clause.to_str())

    return unittest.end(env)

simple_test = unittest.make(_simple_impl)

def _npm_impl(ctx):
    env = unittest.begin(ctx)

    syntax = Spec.SYNTAX.NPM

    expression = "<1.2.3"
    spec = Spec.new(expression, syntax = syntax)

    asserts.equals(env, syntax, spec.syntax)
    asserts.equals(env, expression, spec.expression)
    expected = "<1.2.3"
    asserts.equals(env, expected, spec.clause.to_str())

    expression = ">=1.2.3 <=1.2.5"
    spec = Spec.new(expression, syntax = syntax)

    asserts.equals(env, syntax, spec.syntax)
    asserts.equals(env, expression, spec.expression)
    expected = (
        "AllOf(" +
        'Range(">=", "1.2.3", prerelease_policy="same-patch"), ' +
        'Range("<=", "1.2.5", prerelease_policy="same-patch")' +
        ")"
    )
    asserts.equals(env, expected, spec.clause.to_str())

    expression = "1.2.3 - 1.2.5"
    spec = Spec.new(expression, syntax = syntax)

    asserts.equals(env, syntax, spec.syntax)
    asserts.equals(env, expression, spec.expression)

    # same expected
    asserts.equals(env, expected, spec.clause.to_str())

    expression = "1.2.7 || >=1.2.9 <2.0.0"
    spec = Spec.new(expression, syntax = syntax)

    asserts.equals(env, syntax, spec.syntax)
    asserts.equals(env, expression, spec.expression)
    expected = (
        "AnyOf(" +
        'Range("==", "1.2.7", prerelease_policy="same-patch"), ' +
        "AllOf(" +
        'Range(">=", "1.2.9", prerelease_policy="same-patch"), ' +
        'Range("<", "2.0.0", prerelease_policy="same-patch")' +
        ")" +
        ")"
    )
    asserts.equals(env, expected, spec.clause.to_str())

    return unittest.end(env)

npm_test = unittest.make(_npm_impl)

def _simple_pgver_impl(ctx):
    env = unittest.begin(ctx)

    syntax = Spec.SYNTAX.SIMPLE
    version_scheme = Version.SCHEME.PGVER

    expression = "<16.4"
    spec = Spec.new(expression, version_scheme = version_scheme)

    asserts.equals(env, syntax, spec.syntax)
    asserts.equals(env, expression, spec.expression)
    asserts.equals(env, expression, spec.clause.to_str())

    expression = ">=16.2, <= 16.4"
    spec = Spec.new(expression, version_scheme = version_scheme)

    asserts.equals(env, syntax, spec.syntax)
    asserts.equals(env, expression.replace(" ", ""), spec.expression)
    expected = 'AllOf(Range(">=", "16.2"), Range("<=", "16.4"))'
    asserts.equals(env, expected, spec.clause.to_str())

    return unittest.end(env)

simple_pgver_test = unittest.make(_simple_pgver_impl)

def _npm_pgver_impl(ctx):
    env = unittest.begin(ctx)

    syntax = Spec.SYNTAX.NPM
    version_scheme = Version.SCHEME.PGVER

    expression = "<16.2"
    spec = Spec.new(expression, syntax = syntax, version_scheme = version_scheme)

    asserts.equals(env, syntax, spec.syntax)
    asserts.equals(env, expression, spec.expression)
    expected = "<16.2"
    asserts.equals(env, expected, spec.clause.to_str())

    expression = ">=16.2 <=16.4"
    spec = Spec.new(expression, syntax = syntax, version_scheme = version_scheme)

    asserts.equals(env, syntax, spec.syntax)
    asserts.equals(env, expression, spec.expression)
    expected = (
        "AllOf(" +
        'Range(">=", "16.2", prerelease_policy="same-patch"), ' +
        'Range("<=", "16.4", prerelease_policy="same-patch")' +
        ")"
    )
    asserts.equals(env, expected, spec.clause.to_str())

    expression = "16.2 - 16.4"
    spec = Spec.new(expression, syntax = syntax, version_scheme = version_scheme)

    asserts.equals(env, syntax, spec.syntax)
    asserts.equals(env, expression, spec.expression)

    # same expected
    asserts.equals(env, expected, spec.clause.to_str())

    expression = "16.2 || >=16.4 <17.0"
    spec = Spec.new(expression, syntax = syntax, version_scheme = version_scheme)

    asserts.equals(env, syntax, spec.syntax)
    asserts.equals(env, expression, spec.expression)
    expected = (
        "AnyOf(" +
        'Range("==", "16.2", prerelease_policy="same-patch"), ' +
        "AllOf(" +
        'Range(">=", "16.4", prerelease_policy="same-patch"), ' +
        'Range("<", "17.0", prerelease_policy="same-patch")' +
        ")" +
        ")"
    )
    asserts.equals(env, expected, spec.clause.to_str())

    return unittest.end(env)

npm_pgver_test = unittest.make(_npm_pgver_impl)

TEST_SUITE_NAME = "spec"

TEST_SUITE_TESTS = dict(
    invalid = invalid_test,
    simple = simple_test,
    npm = npm_test,
    simple_pgver = simple_pgver_test,
    npm_pgver = npm_pgver_test,
)

test_suite = lambda: _test_suite(TEST_SUITE_NAME, TEST_SUITE_TESTS)
