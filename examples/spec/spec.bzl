"""e2e spec tests"""

load("@bazel_skylib//lib:unittest.bzl", "asserts", "unittest")
load("@version_utils//spec:spec.bzl", "spec")
load("//:suite.bzl", _examples_suite = "test_suite")

_VERSIONS = ["0.%d.0" % i for i in range(6)]

def _spec_simple_examples_impl(ctx):
    env = unittest.begin(ctx)

    simple = spec.new(">=0.1.0,<0.4.0")

    asserts.true(env, simple.match("0.2.0"))
    asserts.false(env, simple.match("0.4.0"))

    expected = ["0.1.0", "0.2.0", "0.3.0"]

    res = [v.to_str() for v in simple.filter(_VERSIONS)]
    asserts.equals(env, expected, res)

    asserts.equals(env, "0.3.0", simple.select(_VERSIONS).to_str())

    return unittest.end(env)

spec_simple_examples_test = unittest.make(_spec_simple_examples_impl)

def _spec_npm_examples_impl(ctx):
    env = unittest.begin(ctx)

    npm = spec.new(">=0.1.0 <0.3.0", syntax = spec.SYNTAX.NPM)

    asserts.true(env, npm.match("0.2.0"))
    asserts.false(env, npm.match("0.4.0"))

    expected = ["0.1.0", "0.2.0"]

    res = [v.to_str() for v in npm.filter(_VERSIONS)]
    asserts.equals(env, expected, res)

    asserts.equals(env, "0.2.0", npm.select(_VERSIONS).to_str())

    return unittest.end(env)

spec_npm_examples_test = unittest.make(_spec_npm_examples_impl)

SUITE_NAME = "spec"

SUITE = dict(
    spec_simple = spec_simple_examples_test,
    spec_npm = spec_npm_examples_test,
)

examples_suite = lambda: _examples_suite(SUITE_NAME, SUITE)
