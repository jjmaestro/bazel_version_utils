"""version/pgver.bzl unit tests"""

load("@bazel_skylib//lib:unittest.bzl", "asserts", "unittest")
load("//tests:mock.bzl", Mock = "mock")
load("//tests:suite.bzl", _test_suite = "test_suite")
load("//tests/version/internal:utils.bzl", "WILDCARDS")
load("//version:version.bzl", Version = "version")

# buildifier: disable=name-conventions
PgVer = Version.new(Version.SCHEME.PGVER)

def _parse_impl(ctx):
    env = unittest.begin(ctx)

    # invalid values
    for version in (None, 16, 16.4):
        res = PgVer.parse(version, _fail = Mock.fail)
        asserts.true(env, res.startswith("Invalid Postgres version string"), res)

    # empty string
    res = PgVer.parse("", _fail = Mock.fail)
    asserts.equals(env, "Empty version string", res)

    # valid partial version but fails because no partial
    version = "16"
    res = PgVer.parse(version, _fail = Mock.fail)
    asserts.true(env, res.startswith("Invalid Postgres version"))

    # valid partial versions and valid full version
    params = [
        ("16", True, "16", None),
        ("16.x", False, "16", WILDCARDS),
        ("16.*", False, "16", WILDCARDS),
        ("16.0", False, "16.0", None),
        ("16alpha1", False, None, None),
        ("16alpha1+b42", False, None, None),
    ]

    for version, partial, expected, wildcards in params:
        wildcards = wildcards or ()
        expected = version if expected == None else expected
        res = PgVer.parse(version, partial = partial, wildcards = wildcards)
        expected_partial = partial or bool(wildcards)
        asserts.equals(env, expected, res.to_str())
        asserts.equals(env, expected_partial, res._partial)

    return unittest.end(env)

parse_test = unittest.make(_parse_impl)

def _to_str_impl(ctx):
    env = unittest.begin(ctx)

    versions = ["16", "16+b42", "16.0", "16rc1", "16rc1+b42"]

    for idx, expected in enumerate(versions):
        res = PgVer.parse(expected, partial = idx < 2).to_str()
        asserts.equals(env, expected, res)

    return unittest.end(env)

to_str_test = unittest.make(_to_str_impl)

def _truncate_impl(ctx):
    env = unittest.begin(ctx)

    checks = {
        "16.2": [
            ("16.2", "prerelease"),
            ("16.2", "minor"),
            ("16.0", "major"),
        ],
        "16beta1": [
            ("16beta1", "prerelease"),
            ("16.0", "minor"),
            ("16.0", "major"),
        ],
    }

    for sv, params in checks.items():
        for expected, level in params:
            expected = PgVer.parse(expected)
            version = PgVer.parse(sv)
            truncated = version.truncate(level)
            asserts.equals(env, expected.to_str(), truncated.to_str())

    for sv in checks:
        res = PgVer.parse(sv).truncate("patch", _fail = Mock.fail)
        asserts.true(env, res.startswith("Invalid truncation level"))

    return unittest.end(env)

truncate_test = unittest.make(_truncate_impl)

_ORDERED_VERSIONS = [
    "16alpha1",
    "16alpha2",
    "16beta1",
    "16beta2",
    "16rc1",
    "16rc2",
    "16.0",
    "16.1",
    "16.2",
    "17alpha1",
    "17alpha2",
    "17beta1",
    "17beta2",
    "17rc1",
    "17rc2",
    "17.0",
    "17.1",
    "17.2",
    "17",
    "18.1+build.1",
    "18",
]

def _sorting_impl(ctx):
    env = unittest.begin(ctx)

    mixed = [
        PgVer.parse(v, partial = True)
        for v in (
            _ORDERED_VERSIONS[3:5] +
            _ORDERED_VERSIONS[12:16] +
            _ORDERED_VERSIONS[0:3] +
            _ORDERED_VERSIONS[8:12] +
            _ORDERED_VERSIONS[16:] +
            _ORDERED_VERSIONS[5:8]
        )
    ]

    sorted_versions = [sv.to_str() for sv in PgVer.sorted(mixed)]

    asserts.equals(env, _ORDERED_VERSIONS, sorted_versions)

    # sorting is stable
    versions = [
        "16rc1+b",
        "16rc1+b.1",
        "16rc1",
        "16rc2",
        "16.0+b",
        "16.0+b.1",
        "16.0+b.2",
        "16.0",
    ]
    mixed = [
        PgVer.parse(versions[idx])
        for idx in [1, 4, 0, 6, 7, 2, 3, 5]
    ]

    sorted_versions = [sv.to_str() for sv in PgVer.sorted(mixed)]

    asserts.equals(env, versions, sorted_versions)

    return unittest.end(env)

sorting_test = unittest.make(_sorting_impl)

def _cmp_impl(ctx):
    env = unittest.begin(ctx)

    for i, v1 in enumerate(_ORDERED_VERSIONS):
        sv1 = PgVer.parse(v1, partial = True)
        for j, v2 in enumerate(_ORDERED_VERSIONS):
            sv2 = PgVer.parse(v2, partial = True)

            if i < j:
                asserts.true(env, sv1.lt(sv2))
                asserts.true(env, sv2.gt(sv1))

                asserts.false(env, sv1.gt(sv2))
                asserts.true(env, sv1.ne(sv2))
                cmp_res = -1
            elif i > j:
                asserts.true(env, sv1.gt(sv2))
                asserts.true(env, sv2.lt(sv1))

                asserts.false(env, sv1.lt(sv2))
                asserts.true(env, sv1.ne(sv2))
                cmp_res = 1
            else:
                asserts.true(env, sv1.eq(sv2))
                asserts.false(env, sv1.lt(sv2))
                asserts.false(env, sv1.gt(sv2))
                asserts.false(env, sv1.ne(sv2))
                cmp_res = 0

            asserts.equals(env, cmp_res, sv1.cmp(sv2))

    return unittest.end(env)

cmp_test = unittest.make(_cmp_impl)

def _eq_impl(ctx):
    env = unittest.begin(ctx)

    versions = ["16", "16.2", "16alpha1", "16beta1"]

    for idx, v1 in enumerate(versions):
        sv1 = PgVer.parse(v1, partial = idx == 0)
        for jdx, v2 in enumerate(versions):
            sv2 = PgVer.parse(v2, partial = jdx == 0)

            if idx == jdx:
                asserts.true(env, sv1.eq(sv2))
            else:
                asserts.false(env, sv1.eq(sv2))

    # build is ignored when comparing
    versions = [
        ("16.2", "16.2+b001"),
        ("17rc1", "17rc1+b001"),
    ]
    for v1, v2 in versions:
        sv1 = PgVer.parse(v1)
        sv2 = PgVer.parse(v2)
        asserts.true(env, sv1.eq(sv2))

    return unittest.end(env)

eq_test = unittest.make(_eq_impl)

def _lt_impl(ctx):
    env = unittest.begin(ctx)

    versions = ["16.0", "17alpha1", "17.0", "17.1", "17.2"]

    for idx in range(len(versions) - 1):
        sv1 = PgVer.parse(versions[idx])
        sv2 = PgVer.parse(versions[idx + 1])
        asserts.true(env, sv1.lt(sv2))
        asserts.true(env, sv2.gt(sv1))

    for idx in range(len(_ORDERED_VERSIONS) - 1):
        sv1 = PgVer.parse(_ORDERED_VERSIONS[idx], partial = True)
        sv2 = PgVer.parse(_ORDERED_VERSIONS[idx + 1], partial = True)
        asserts.true(env, sv1.lt(sv2))
        asserts.true(env, sv2.gt(sv1))

    # partial ordering:  17.0 < 17
    sv1 = PgVer.parse("17", partial = True)
    sv2 = PgVer.parse("17.0", partial = True)
    asserts.true(env, sv2.lt(sv1))

    return unittest.end(env)

lt_test = unittest.make(_lt_impl)

def _is_impl(ctx):
    env = unittest.begin(ctx)

    for sv in (None, 16, (16, 2), [16, 2], struct(major = 16, minor = 2)):
        asserts.false(env, PgVer.is_(sv))

    sv = PgVer.parse("16.2")
    asserts.true(env, PgVer.is_(sv))

    return unittest.end(env)

is_test = unittest.make(_is_impl)

def _compare_impl(ctx):
    env = unittest.begin(ctx)

    v1 = "16.2"
    sv2 = PgVer.parse("16.3")

    comparisons = [
        (v1, v1, 0),
        (v1, sv2, -1),
        (sv2, sv2, 0),
        (sv2, v1, 1),
    ]

    for v1, v2, expected in comparisons:
        res = PgVer.compare(v1, v2)
        asserts.equals(env, expected, res)

    return unittest.end(env)

compare_test = unittest.make(_compare_impl)

def _bumping_impl(ctx):
    env = unittest.begin(ctx)

    checks = dict(
        major = [
            ("16beta1", "16.0"),
            ("16.0", "17.0"),
            ("16.1", "17.0"),
        ],
        minor = [
            ("16.0", "16.1"),
            ("16.1", "16.2"),
            ("17beta1", "17.0"),
        ],
    )

    for level, params in checks.items():
        for version, expected in params:
            sv = PgVer.parse(version)
            nv = getattr(sv, "bump")(level)
            asserts.equals(env, expected, nv.to_str())

    err = PgVer.parse("16.0").bump("patch", _fail = Mock.fail)
    asserts.true(env, err.startswith("Invalid bump level"))

    return unittest.end(env)

bumping_test = unittest.make(_bumping_impl)

def _parse_re_impl(ctx):
    env = unittest.begin(ctx)

    params = [
        ("16", ("16", None, (), ())),
        ("16.2", ("16", "2", (), ())),
        ("16rc1", ("16", None, ("rc", "1"), ())),
        ("16.2+b01", ("16", "2", (), ("b01",))),
        ("16rc1+b01", ("16", None, ("rc", "1"), ("b01",))),
    ]

    params += [
        (w, (w, None, (), ()))
        for w in WILDCARDS[:-1]
    ]

    params += [
        ("16.%s" % w, ("16", w, (), ()))
        for w in WILDCARDS[:-1]
    ]

    for version, parts in params:
        res = PgVer.__test__._parse_re(version)
        asserts.equals(env, parts, res)

    return unittest.end(env)

parse_re_test = unittest.make(_parse_re_impl)

TEST_SUITE_NAME = "pgver"

TEST_SUITE_TESTS = dict(
    parse = parse_test,
    to_str = to_str_test,
    truncate = truncate_test,
    # sorting
    sorting = sorting_test,
    # comparing
    cmp = cmp_test,
    eq = eq_test,
    lt = lt_test,
    # compare
    is_ = is_test,
    compare = compare_test,
    # bumping
    bumping = bumping_test,
    # internal
    _parse_re = parse_re_test,
)

test_suite = lambda: _test_suite(TEST_SUITE_NAME, TEST_SUITE_TESTS)
