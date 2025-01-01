"""e2e foo tests"""

load("@bazel_skylib//lib:unittest.bzl", "unittest")

# load("@module_name//foo:foo.bzl", "foo")
load("//:suite.bzl", _examples_suite = "test_suite")

def _foo_examples_impl(ctx):
    env = unittest.begin(ctx)

    # foo.something()

    return unittest.end(env)

foo_examples_test = unittest.make(_foo_examples_impl)

SUITE_NAME = "foo"

SUITE = dict(
    foo = foo_examples_test,
)

examples_suite = lambda: _examples_suite(SUITE_NAME, SUITE)
