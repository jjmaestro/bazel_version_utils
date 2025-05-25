"""e2e pgver tests"""

load("@bazel_skylib//lib:unittest.bzl", "asserts", "unittest")
load("@version_utils//version:pgver.bzl", "pgver")
load("//:suite.bzl", _examples_suite = "test_suite")

def _pgver_examples_impl(ctx):
    env = unittest.begin(ctx)

    version = pgver.parse("17.2+b42")

    asserts.equals(env, 17, version.major)
    asserts.equals(env, 2, version.minor)

    asserts.equals(env, ("b42",), version.build)

    asserts.equals(env, "17.2+b42", version.to_str())

    return unittest.end(env)

pgver_examples_test = unittest.make(_pgver_examples_impl)

SUITE_NAME = "pgver"

SUITE = dict(
    pgver = pgver_examples_test,
)

examples_suite = lambda: _examples_suite(SUITE_NAME, SUITE)
