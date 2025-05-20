"""spec/internal:clauses.bzl unit tests"""

load("@bazel_skylib//lib:unittest.bzl", "asserts", "unittest")

# buildifier: disable=bzl-visibility
load("//spec/internal:clauses.bzl", Clauses = "clauses")
load("//tests:mock.bzl", Mock = "mock")
load("//tests:suite.bzl", _test_suite = "test_suite")

def _clause_impl(ctx):
    env = unittest.begin(ctx)

    c1 = Clauses.__test__._clause_new({"foo": 42}, _fail = Mock.fail)

    asserts.equals(env, "Clause", c1.__class__)
    asserts.equals(env, 42, c1.foo)

    for attr in ("and_", "or_", "eq"):
        asserts.equals(env, "NotImplemented", getattr(c1, attr)(c1))

    asserts.equals(env, "NotImplemented", c1.match("1.2.3"))

    return unittest.end(env)

clause_test = unittest.make(_clause_impl)

def _range_impl(ctx):
    env = unittest.begin(ctx)

    target = "1.2.1"

    op = "=="
    r = Clauses.Range.new(op, target = target)
    expected = "%s%s" % (op, target)
    asserts.equals(env, expected, r.to_str())
    asserts.true(env, r.match(target))
    asserts.false(env, r.match("1.2.0"))

    op = "!="
    r = Clauses.Range.new(op, target = target)
    expected = "%s%s" % (op, target)
    asserts.equals(env, expected, r.to_str())
    asserts.true(env, r.match("1.2.0"))
    asserts.false(env, r.match(target))

    op = "foo"
    r = Clauses.Range.new(op, target = target, _fail = Mock.fail)
    res = r.match(target)
    asserts.equals(env, res, "Unknown operator: %s" % op)

    return unittest.end(env)

range_test = unittest.make(_range_impl)

def _anyall_range_impl(ctx):
    env = unittest.begin(ctx)

    ranges_args = [
        (">=", "1.2.2"),
        ("<", "1.2.4"),
        (">", "1.2.4"),
        ("<=", "1.2.6"),
    ]

    ranges = []
    rreprs = []

    for op, target in ranges_args:
        r = Clauses.Range.new(op, target = target)

        e_str = "%s%s" % (op, target)
        asserts.equals(env, e_str, r.to_str())

        e_repr = "Range(%r, %r)" % (op, target)
        asserts.equals(env, e_repr, r.repr())

        ranges.append(r)
        rreprs.append(r.repr())

    # [1.2.2, *] & [*, 1.2.4) --> [1.2.2, 1.2.4)
    r1 = ranges[0].and_(ranges[1])

    r1str = "AllOf(%s, %s)" % (rreprs[0], rreprs[1])
    asserts.equals(env, r1str, r1.repr())
    asserts.equals(env, r1str, r1.to_str())

    checks1 = [
        ("1.2.0", False),
        ("1.2.1", False),
        ("1.2.2", True),
        ("1.2.3", True),
        ("1.2.4", False),
        ("1.2.5", False),
    ]

    for version, expected in checks1:
        asserts.equals(env, expected, r1.match(version))

    # (1.2.4, *] & [*, 1.2.6] --> (1.2.4, 1.2.6]
    r2 = ranges[2].and_(ranges[3])

    r2str = "AllOf(%s, %s)" % (rreprs[2], rreprs[3])
    asserts.equals(env, r2str, r2.repr())
    asserts.equals(env, r2str, r2.to_str())

    checks2 = [
        ("1.2.3", False),
        ("1.2.4", False),
        ("1.2.5", True),
        ("1.2.6", True),
        ("1.2.7", False),
    ]

    for version, expected in checks2:
        asserts.equals(env, expected, r2.match(version))

    r3 = r1.or_(r2)  # [1.2.2, 1.2.4) | (1.2.4, 1.2.6]
    r3str = "AnyOf(%s, %s)" % (r1str, r2str)

    asserts.equals(env, r3str, r3.repr())
    asserts.equals(env, r3str, r3.to_str())

    checks3 = {v: expected for v, expected in checks1}
    for v, expected in checks2:
        if v in checks3:
            checks3[v] = checks3[v] or expected
        else:
            checks3[v] = expected

    for version, expected in checks3.items():
        asserts.equals(env, expected, r3.match(version))

    # [1.2.2, 1.2.4) & (1.2.4, 1.2.6] --> EMPTY set, no version can satisfy
    # being in BOTH intervals at the same time
    r4 = r1.and_(r2)
    r4str = "AllOf(%s, %s, %s, %s)" % tuple(rreprs)

    asserts.equals(env, r4str, r4.repr())
    asserts.equals(env, r4str, r4.to_str())

    for version, _ in checks1 + checks2:
        asserts.equals(env, False, r4.match(version))

    return unittest.end(env)

anyall_range_test = unittest.make(_anyall_range_impl)

def _simplify_impl(ctx):
    env = unittest.begin(ctx)

    rl = Clauses.Range.new(">=", "1.0.0")
    rr = Clauses.Range.new("<", "2.0.0")

    c1 = rl.and_(rr)
    c2 = rl.and_(rr)

    cs1 = c1.simplify()
    cs2 = c2.simplify()

    asserts.true(env, cs1.eq(cs2))

    c1 = rl.and_(c1).and_(rr)
    c1 = c1.and_(c2)

    cs1 = c1.simplify()
    cs2 = c2.simplify()

    asserts.true(env, cs1.eq(cs2))

    return unittest.end(env)

simplify_test = unittest.make(_simplify_impl)

TEST_SUITE_NAME = "clauses"

TEST_SUITE_TESTS = dict(
    clause = clause_test,
    range = range_test,
    anyall_range = anyall_range_test,
    simplify = simplify_test,
)

test_suite = lambda: _test_suite(TEST_SUITE_NAME, TEST_SUITE_TESTS)
