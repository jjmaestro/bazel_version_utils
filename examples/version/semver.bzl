"""e2e semver tests"""

load("@bazel_skylib//lib:unittest.bzl", "asserts", "unittest")
load("@version_utils//version:semver.bzl", "semver")
load("//:suite.bzl", _examples_suite = "test_suite")

def _semver_examples_impl(ctx):
    env = unittest.begin(ctx)

    version = semver.parse("1.0.2-alpha+build.2025-01-15")

    asserts.equals(env, 1, version.major)
    asserts.equals(env, 0, version.minor)
    asserts.equals(env, 2, version.patch)

    asserts.equals(env, ("alpha",), version.prerelease)

    asserts.equals(env, ("build", "2025-01-15"), version.build)

    asserts.equals(env, "1.0.2-alpha+build.2025-01-15", version.to_str())

    return unittest.end(env)

semver_examples_test = unittest.make(_semver_examples_impl)

SUITE_NAME = "semver"

SUITE = dict(
    semver = semver_examples_test,
)

examples_suite = lambda: _examples_suite(SUITE_NAME, SUITE)
