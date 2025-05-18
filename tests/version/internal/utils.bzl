"""version/internal/utils.bzl unit tests"""

load("@bazel_skylib//lib:unittest.bzl", "asserts", "unittest")
load("//tests:mock.bzl", Mock = "mock")
load("//tests:suite.bzl", _test_suite = "test_suite")

# buildifier: disable=bzl-visibility
load("//version/internal:utils.bzl", "utils")

def _coerce_impl(ctx):
    env = unittest.begin(ctx)

    # int
    value = 123
    res = utils.coerce(value)
    asserts.equals(env, 123, res)

    # numeric string
    value = "0123"
    res = utils.coerce(value)
    asserts.equals(env, 123, res)

    # None with and without partial
    value = None
    for partial, expected in [(False, "Can't coerce value: None"), (True, None)]:
        res = utils.coerce(value, partial = partial, _fail = Mock.fail)
        asserts.equals(env, expected, res)

    # something else
    value = (1, 2)
    res = utils.coerce(value, _fail = Mock.fail)
    asserts.equals(env, "Can't coerce value: (1, 2)", res)

    return unittest.end(env)

coerce_test = unittest.make(_coerce_impl)

def _has_leading_zero_impl(ctx):
    env = unittest.begin(ctx)

    # has leading zero and not allowing it (by default)
    value = "0123"
    res = utils.has_leading_zero(value)
    asserts.true(env, res)

    # has leading zero but it's allowed
    value = "0123"
    res = utils.has_leading_zero(value, allow_leading_zeroes = True)
    asserts.false(env, res)

    # single-digit zeros are not considered "leading zeros"
    value = "0"
    for allow_leading_zeroes in (False, True):
        res = utils.has_leading_zero(value, allow_leading_zeroes)
        asserts.false(env, res)

    # even if it starts with leading zero, if it's not a full number, it's allowed
    value = "01-alpha"
    res = utils.has_leading_zero(value, allow_leading_zeroes = True)
    asserts.false(env, res)

    # something else
    for value in (123, (1, 2)):
        asserts.false(env, utils.has_leading_zero(value))

    return unittest.end(env)

has_leading_zero_test = unittest.make(_has_leading_zero_impl)

TEST_SUITE_NAME = "utils"

TEST_SUITE_TESTS = dict(
    _coerce = coerce_test,
    _has_leading_zero = has_leading_zero_test,
)

test_suite = lambda: _test_suite(TEST_SUITE_NAME, TEST_SUITE_TESTS)
