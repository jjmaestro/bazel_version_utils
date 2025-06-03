"""
NPM spec unit tests

Mirrors python-semanticversion/tests/test_npm.py
"""

load("@bazel_skylib//lib:unittest.bzl", "asserts", "unittest")
load("//spec:spec.bzl", Spec = "spec")
load("//tests:mock.bzl", Mock = "mock")
load("//tests:suite.bzl", _test_suite = "test_suite")

def _spec_impl(ctx):
    env = unittest.begin(ctx)

    # examples = { expression: ([match = True], [match = False]) }
    examples = dict([
        (">=1.2.7", (
            ["1.2.7", "1.2.8", "1.3.9"],
            ["1.2.6", "1.1.0"],
        )),
        (">=1.2.7 <1.3.0", (
            ["1.2.7", "1.2.8", "1.2.99"],
            ["1.2.6", "1.3.0", "1.1.0"],
        )),
        ("1.2.7 || >=1.2.9 <2.0.0", (
            ["1.2.7", "1.2.9", "1.4.6"],
            ["1.2.8", "2.0.0"],
        )),
        (">1.2.3-alpha.3", (
            ["1.2.3-alpha.7", "3.4.5"],
            ["1.2.3-alpha.3", "3.4.5-alpha.9"],
        )),
        (">=1.2.3-alpha.3", (
            ["1.2.3-alpha.3", "1.2.3-alpha.7", "3.4.5"],
            ["1.2.3-alpha.2", "3.4.5-alpha.9"],
        )),
        ("<=1.2.3-beta.3", (
            ["1.2.3-beta.2", "1.2.3-alpha.7"],
            ["1.2.3-beta.4", "1.2.3-rc.1", "1.1.1"],
        )),
        (">1.2.3-alpha <1.2.3-beta", (
            ["1.2.3-alpha.0", "1.2.3-alpha.1"],
            ["1.2.3", "1.2.3-beta.0", "1.2.3-bravo"],
        )),
        ("1.2.3 - 2.3.4", (
            ["1.2.3", "1.2.99", "2.2.0", "2.3.4", "2.3.4+b42"],
            ["1.2.0", "1.2.3-alpha.1", "2.3.5"],
        )),
        ("~1.2.3-beta.2", (
            ["1.2.3-beta.2", "1.2.3-beta.4", "1.2.4"],
            ["1.2.4-beta.2", "1.3.0"],
        )),
    ])

    for expression, cases in examples.items():
        match, nomatch = cases

        spec = Spec.new(expression, syntax = Spec.SYNTAX.NPM)

        for version in match:
            asserts.true(env, spec.match(version))

        for version in nomatch:
            asserts.false(env, spec.match(version))

    return unittest.end(env)

spec_test = unittest.make(_spec_impl)

def _expand_impl(ctx):
    env = unittest.begin(ctx)

    expansions = dict([
        # Hyphen ranges
        ("1.2.3 - 2.3.4", ">=1.2.3 <=2.3.4"),
        ("1.2 - 2.3.4", ">=1.2.0 <=2.3.4"),
        ("1.2.3 - 2.3", ">=1.2.3 <2.4.0"),
        ("1.2.3 - 2", ">=1.2.3 <3"),

        # X-Ranges
        ("*", ">=0.0.0"),
        (">=*", ">=0.0.0"),
        ("1.x", ">=1.0.0 <2.0.0"),
        ("1.2.x", ">=1.2.0 <1.3.0"),
        ("", "*"),
        ("x", "*"),
        ("1", "1.x.x"),
        ("1.x.x", ">=1.0.0 <2.0.0"),
        ("1.2", "1.2.x"),

        # Partial GT LT Ranges
        (">=1", ">=1.0.0"),
        (">1", ">=2.0.0"),
        (">1.2", ">=1.3.0"),
        ("<1", "<1.0.0"),

        # Tilde ranges
        ("~1.2.3", ">=1.2.3 <1.3.0"),
        ("~1.2", ">=1.2.0 <1.3.0"),
        ("~1", ">=1.0.0 <2.0.0"),
        ("~0.2.3", ">=0.2.3 <0.3.0"),
        ("~0.2", ">=0.2.0 <0.3.0"),
        ("~0", ">=0.0.0 <1.0.0"),
        ("~1.2.3-beta.2", ">=1.2.3-beta.2 <1.3.0"),
        ("~>1.2.3", ">=1.2.3 <1.3.0"),

        # Caret ranges
        ("^1.2.3", ">=1.2.3 <2.0.0"),
        ("^0.2.3", ">=0.2.3 <0.3.0"),
        ("^0.0.3", ">=0.0.3 <0.0.4"),
        ("^1.2.3-beta.2", ">=1.2.3-beta.2 <2.0.0"),
        ("^0.0.3-beta", ">=0.0.3-beta <0.0.4"),
        ("^1.2.x", ">=1.2.0 <2.0.0"),
        ("^0.0.x", ">=0.0.0 <0.1.0"),
        ("^0.0", ">=0.0.0 <0.1.0"),
        ("^1.x", ">=1.0.0 <2.0.0"),
        ("^0.x", ">=0.0.0 <1.0.0"),
        ("^0", ">=0.0.0 <1.0.0"),
    ])

    # With whitespace
    wexpansions = dict([
        # NOTE:
        # We want to be able to parse these because npm-server does parse them
        # even though these don't strictly adhere to the NPM grammar.
        ("1.2  -  2.3.4    ||   >   1.2.3", ">=1.2.0 <=2.3.4 || >1.2.3"),
        (">= 1.2.3", ">=1.2.3"),
        (">=   1.2.3", ">=1.2.3"),
        ("   >=1.2.3 <2.0.0    ", ">=1.2.3 <2.0.0"),
        (">= 1.2.3 <  2.0.0", ">=1.2.3 <2.0.0"),
        (">=1.2.3 < 2.0.0", ">=1.2.3 <2.0.0"),
        (">= 1.2.3 < 2.0.0", ">=1.2.3 <2.0.0"),
        (">=  1.2.3 <    2.0.0", ">=1.2.3 <2.0.0"),
        ("   >=1.2.3 <2.0.0    ", ">=1.2.3 <2.0.0"),
        ("1.2.7 ||    >=1.2.9  <2.0.0 ", "1.2.7 || >=1.2.9 <2.0.0"),
        ("1.2.7 ||    >= 1.2.9   < 2.0.0 ", "1.2.7 || >=1.2.9 <2.0.0"),
        ("^ 1.2.3", ">=1.2.3 <2.0.0"),
        ("^   1.2.3", ">=1.2.3 <2.0.0"),
        ("~ 1.2.3", ">=1.2.3 <1.3.0"),
        ("~    1.2.3", ">=1.2.3 <1.3.0"),
    ])

    expansions |= wexpansions

    for source, expanded in expansions.items():
        s1 = Spec.new(source, syntax = Spec.SYNTAX.NPM)
        s2 = Spec.new(expanded, syntax = Spec.SYNTAX.NPM)
        asserts.true(env, s1.clause.eq(s2.clause))

    return unittest.end(env)

expand_test = unittest.make(_expand_impl)

def _invalid_spec_impl(ctx):
    def is_error(res):
        errors = (
            "Empty version string",
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
        "==0.1.2",
        ">>0.1.2",
        "> = 0.1.2",
        "<=>0.1.2",
        "~1.2.3beta",
        "~=1.2.3",
        ">01.02.03",
        "!0.1.2",
        "!=0.1.2",
    ]

    for expression in invalid_specs:
        res = Spec.new(expression, syntax = Spec.SYNTAX.NPM, _fail = Mock.fail)
        asserts.true(env, is_error(res))

    return unittest.end(env)

invalid_spec_test = unittest.make(_invalid_spec_impl)

def _simplify_impl(ctx):
    env = unittest.begin(ctx)

    expressions = dict([
        ("1.0.0 || 1.0.0", "1.0.0"),
    ])

    for left, right in expressions.items():
        s1 = Spec.new(left, syntax = Spec.SYNTAX.NPM)
        s2 = Spec.new(right, syntax = Spec.SYNTAX.NPM)

        ss1 = s1.clause.simplify()
        ss2 = s2.clause.simplify()

        asserts.true(env, ss1.eq(ss2))

    return unittest.end(env)

simplify_test = unittest.make(_simplify_impl)

def _equivalent_impl(ctx):
    """
    Like _expand_impl, but simplifying both sides

    NOTE:
    Some specs can be equivalent but don't currently simplify to the same
    clauses.
    """

    env = unittest.begin(ctx)

    expansions = dict([
        ("||", "*"),
    ])

    for left, right in expansions.items():
        s1 = Spec.new(left, syntax = Spec.SYNTAX.NPM)
        s2 = Spec.new(right, syntax = Spec.SYNTAX.NPM)

        ss1 = s1.clause.simplify()
        ss2 = s2.clause.simplify()

        asserts.true(env, ss1.eq(ss2))

    return unittest.end(env)

equivalent_test = unittest.make(_equivalent_impl)

TEST_SUITE_NAME = "spec_npm"

TEST_SUITE_TESTS = dict(
    spec = spec_test,
    invalid_spec = invalid_spec_test,
    expand = expand_test,
    simplify = simplify_test,
    equivalent = equivalent_test,
)

test_suite = lambda: _test_suite(TEST_SUITE_NAME, TEST_SUITE_TESTS)
