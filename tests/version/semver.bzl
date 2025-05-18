"""version/semver.bzl unit tests"""

load("@bazel_skylib//lib:unittest.bzl", "asserts", "unittest")
load("//tests:mock.bzl", Mock = "mock")
load("//tests:suite.bzl", _test_suite = "test_suite")
load("//version:semver.bzl", SemVer = "semver")

def _is_valid_normal_version_number_impl(ctx):
    env = unittest.begin(ctx)

    # None with and without partial
    value = None
    for partial, expected in [(False, False), (True, True)]:
        res = SemVer.__test__._is_valid_normal_version_number(value, partial = partial)
        asserts.equals(env, expected, res)

    # int / valid numeric string
    for value in (123, "123"):
        res = SemVer.__test__._is_valid_normal_version_number(value)
        asserts.true(env, res)

    # invalid int
    value = -1
    res = SemVer.__test__._is_valid_normal_version_number(value)
    asserts.false(env, res)

    # invalid numeric string
    for value in ("1.0", "-1.0", "01"):
        res = SemVer.__test__._is_valid_normal_version_number(value)
        asserts.false(env, res)

    return unittest.end(env)

is_valid_normal_version_number_test = unittest.make(_is_valid_normal_version_number_impl)

def _is_valid_prerelease_identifier_impl(ctx):
    env = unittest.begin(ctx)

    # int
    value = 123
    res = SemVer.__test__._is_valid_prerelease_identifier(value)
    asserts.true(env, res)

    # numeric string
    res = SemVer.__test__._is_valid_prerelease_identifier("123")
    asserts.true(env, res)

    # leading zeros not allowed
    value = "0123"
    res = SemVer.__test__._is_valid_prerelease_identifier(value)
    asserts.false(env, res)

    # alphnumeric strings
    for value in ("alpha.1", "beta-1", "foo.1-123", "alpha-1.2.3"):
        res = all([
            SemVer.__test__._is_valid_prerelease_identifier(identifier)
            for identifier in value.split(".")
        ])
        asserts.true(env, res)

    # invalid numeric strings
    for value in ("rc_1.0", "rc/1.0"):
        res = all([
            SemVer.__test__._is_valid_prerelease_identifier(identifier)
            for identifier in value.split(".")
        ])
        asserts.false(env, res)

    # invalid empty string unless requested
    for allow_empty in (False, True):
        res = SemVer.__test__._is_valid_prerelease_identifier("", allow_empty)
        asserts.equals(env, allow_empty, res)

    return unittest.end(env)

is_valid_prerelease_identifier_test = unittest.make(_is_valid_prerelease_identifier_impl)

def _is_valid_build_identifier_impl(ctx):
    env = unittest.begin(ctx)

    # int
    value = 123
    res = SemVer.__test__._is_valid_build_identifier(value)
    asserts.true(env, res)

    # numeric string
    res = SemVer.__test__._is_valid_build_identifier("123")
    asserts.true(env, res)

    # leading zeros allowed
    value = "0123"
    res = SemVer.__test__._is_valid_build_identifier(value)
    asserts.true(env, res)

    # alphnumeric strings
    for value in ("build.1", "build-1", "foo.1-123", "build-1.2.3"):
        res = all([
            SemVer.__test__._is_valid_build_identifier(identifier)
            for identifier in value.split(".")
        ])
        asserts.true(env, res)

    # invalid numeric strings
    for value in ("build_1.0", "build/1.0"):
        res = all([
            SemVer.__test__._is_valid_build_identifier(identifier)
            for identifier in value.split(".")
        ])
        asserts.false(env, res)

    # invalid empty string unless requested
    for allow_empty in (False, True):
        res = SemVer.__test__._is_valid_build_identifier("", allow_empty)
        asserts.equals(env, allow_empty, res)

    return unittest.end(env)

is_valid_build_identifier_test = unittest.make(_is_valid_build_identifier_impl)

def _parse_impl(ctx):
    env = unittest.begin(ctx)

    # invalid values
    for version in (None, 1, 1.2):
        res = SemVer.parse(version, _fail = Mock.fail)
        asserts.true(env, res.startswith("Invalid version string"), res)

    # empty string
    res = SemVer.parse("", _fail = Mock.fail)
    asserts.equals(env, "Empty version string", res)

    # valid partial version but fails because no partial
    version = "1.2"
    res = SemVer.parse(version, _fail = Mock.fail)
    asserts.true(env, res.startswith("Invalid semantic version"))

    # valid partial versions and valid full version
    params = [
        ("1.2", True, "1.2"),
        ("1.2.3", False, None),
        ("1.2.3-alpha.1+build-4.5", False, None),
    ]

    for version, partial, expected in params:
        expected = version if expected == None else expected
        res = SemVer.parse(version, partial = partial)
        asserts.equals(env, expected, res.to_str())
        asserts.equals(env, partial, res._partial)

    return unittest.end(env)

parse_test = unittest.make(_parse_impl)

def _to_str_impl(ctx):
    env = unittest.begin(ctx)

    versions = ["1", "1.2", "1.2.3", "1.2.3-rc.1", "1.2.3+b001", "1.2.3-rc1+b001"]

    for idx, expected in enumerate(versions):
        res = SemVer.parse(expected, partial = idx < 2).to_str()
        asserts.equals(env, expected, res)

    return unittest.end(env)

to_str_test = unittest.make(_to_str_impl)

def _truncate_impl(ctx):
    env = unittest.begin(ctx)

    sv = "3.2.1-pre+build"

    params = [
        ("3.2.1-pre+build", "build"),
        ("3.2.1-pre", "prerelease"),
        ("3.2.1", "patch"),
        ("3.2.0", "minor"),
        ("3.0.0", "major"),
    ]

    for expected, level in params:
        expected = SemVer.parse(expected)
        truncated = SemVer.parse(sv).truncate(level)
        asserts.equals(env, expected.to_str(), truncated.to_str())

    res = SemVer.parse(sv).truncate("invalid_level", _fail = Mock.fail)
    asserts.true(env, res.startswith("Invalid truncation level"))

    return unittest.end(env)

truncate_test = unittest.make(_truncate_impl)

_ORDERED_VERSIONS = [
    "1.0.0-0.3.7",
    "1.0.0-a",
    "1.0.0-a.1",
    "1.0.0-a1",
    "1.0.0-alpha",
    "1.0.0-alpha.1",
    "1.0.0-alpha.beta",
    "1.0.0-beta",
    "1.0.0-beta.2",
    "1.0.0-beta.11",
    "1.0.0-rc.1",
    "1.0.0-x.1.z.92",
    "1.0.0-x.7.z.92",
    "1.0.0-x-y-z.--",
    "1.0.0",
    "1.0",
    "1.3.7+build.1",
    "1",
]

def _sorting_impl(ctx):
    env = unittest.begin(ctx)

    mixed = [
        SemVer.parse(v, partial = True)
        for v in (
            _ORDERED_VERSIONS[3:5] +
            _ORDERED_VERSIONS[12:16] +
            _ORDERED_VERSIONS[0:3] +
            _ORDERED_VERSIONS[8:12] +
            _ORDERED_VERSIONS[16:] +
            _ORDERED_VERSIONS[5:8]
        )
    ]

    sorted_versions = [sv.to_str() for sv in SemVer.sorted(mixed)]

    asserts.equals(env, _ORDERED_VERSIONS, sorted_versions)

    # sorting is stable
    versions = [
        "0.1.0-a+b",
        "0.1.0-a+b.1",
        "0.1.0-a",
        "0.1.0-a1",
        "0.1.0-a2",
        "0.1.0+b",
        "0.1.0+b.1",
        "0.1.0+b.2",
        "0.1.0",
    ]
    mixed = [
        SemVer.parse(versions[idx])
        for idx in [1, 4, 0, 6, 7, 2, 3, 5, 8]
    ]

    sorted_versions = [sv.to_str() for sv in SemVer.sorted(mixed)]

    asserts.equals(env, versions, sorted_versions)

    return unittest.end(env)

sorting_test = unittest.make(_sorting_impl)

def _cmp_impl(ctx):
    env = unittest.begin(ctx)

    for i, v1 in enumerate(_ORDERED_VERSIONS):
        sv1 = SemVer.parse(v1, partial = True)
        for j, v2 in enumerate(_ORDERED_VERSIONS):
            sv2 = SemVer.parse(v2, partial = True)

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

    versions = ["1", "1.2", "1.2.3", "1.2.3-rc.1"]

    for idx, v1 in enumerate(versions):
        sv1 = SemVer.parse(v1, partial = idx < 2)
        for jdx, v2 in enumerate(versions):
            sv2 = SemVer.parse(v2, partial = jdx < 2)

            if idx == jdx:
                asserts.true(env, sv1.eq(sv2))
            else:
                asserts.false(env, sv1.eq(sv2))

    # build is ignored when comparing
    versions = [
        ("1.2.3", "1.2.3+b001"),
        ("1.2.3-rc.1", "1.2.3-rc.1+b001"),
    ]
    for v1, v2 in versions:
        sv1 = SemVer.parse(v1)
        sv2 = SemVer.parse(v2)
        asserts.true(env, sv1.eq(sv2))

    return unittest.end(env)

eq_test = unittest.make(_eq_impl)

def _lt_impl(ctx):
    env = unittest.begin(ctx)

    versions = ["1.0.0", "2.0.0", "2.1.0", "2.1.1"]

    for idx in range(len(versions) - 1):
        sv1 = SemVer.parse(versions[idx])
        sv2 = SemVer.parse(versions[idx + 1])
        asserts.true(env, sv1.lt(sv2))
        asserts.true(env, sv2.gt(sv1))

    for idx in range(len(_ORDERED_VERSIONS) - 1):
        sv1 = SemVer.parse(_ORDERED_VERSIONS[idx], partial = True)
        sv2 = SemVer.parse(_ORDERED_VERSIONS[idx + 1], partial = True)
        asserts.true(env, sv1.lt(sv2))
        asserts.true(env, sv2.gt(sv1))

    # partial ordering:  1.0.0 < 1.0 < 1
    sv1 = SemVer.parse("1", partial = True)
    sv2 = SemVer.parse("1.0", partial = True)
    sv3 = SemVer.parse("1.0.0")
    asserts.true(env, sv3.lt(sv2))
    asserts.true(env, sv2.lt(sv1))

    return unittest.end(env)

lt_test = unittest.make(_lt_impl)

def _is_impl(ctx):
    env = unittest.begin(ctx)

    for sv in (None, 1, (1, 2), [1, 2], struct(major = 1, minor = 2, patch = 3)):
        asserts.false(env, SemVer.is_(sv))

    sv = SemVer.parse("1.2.3")
    asserts.true(env, SemVer.is_(sv))

    return unittest.end(env)

is_test = unittest.make(_is_impl)

def _compare_impl(ctx):
    env = unittest.begin(ctx)

    v1 = "1.2.3"
    sv2 = SemVer.parse("1.2.4")

    comparisons = [
        (v1, v1, 0),
        (v1, sv2, -1),
        (sv2, sv2, 0),
        (sv2, v1, 1),
    ]

    for v1, v2, expected in comparisons:
        res = SemVer.compare(v1, v2)
        asserts.equals(env, expected, res)

    return unittest.end(env)

compare_test = unittest.make(_compare_impl)

def _bumping_impl(ctx):
    env = unittest.begin(ctx)

    checks = dict(
        major = [
            ("1.0.0", "2.0.0"),
            ("1.1.0", "2.0.0"),
            ("1.0.1", "2.0.0"),
            ("1.0.0-pre", "1.0.0"),
            ("1.1.0-pre", "2.0.0"),
            ("1.0.1-pre", "2.0.0"),
        ],
        minor = [
            ("1.0.0", "1.1.0"),
            ("1.1.0", "1.2.0"),
            ("1.0.1", "1.1.0"),
            ("1.0.0-pre", "1.0.0"),
            ("1.1.0-pre", "1.1.0"),
            ("1.0.1-pre", "1.1.0"),
        ],
        patch = [
            ("1.0.0", "1.0.1"),
            ("1.1.0", "1.1.1"),
            ("1.0.1", "1.0.2"),
            ("1.0.0-pre", "1.0.0"),
            ("1.1.0-pre", "1.1.0"),
            ("1.0.1-pre", "1.0.1"),
        ],
    )

    for level, params in checks.items():
        for version, expected in params:
            # with and without build, it doesn't affect the results
            for full_version in (version, "%s+%s" % (version, "build")):
                sv = SemVer.parse(full_version)
                nv = getattr(sv, "bump")(level)
                asserts.equals(env, expected, nv.to_str())

    return unittest.end(env)

bumping_test = unittest.make(_bumping_impl)

def _parse_re_impl(ctx):
    env = unittest.begin(ctx)

    params = [
        ("1", ("1", None, None, (), ())),
        ("1.2", ("1", "2", None, (), ())),
        ("1.2.3", ("1", "2", "3", (), ())),
        ("1.2-rc.1", ("1", "2", None, ("rc", "1"), ())),
        ("1.2-rc.1+b01", ("1", "2", None, ("rc", "1"), ("b01",))),
        ("1.2.3-rc.1+b01", ("1", "2", "3", ("rc", "1"), ("b01",))),
    ]

    for version, parts in params:
        res = SemVer.__internal__._parse_re(version)
        asserts.equals(env, parts, res)

    return unittest.end(env)

parse_re_test = unittest.make(_parse_re_impl)

TEST_SUITE_NAME = "semver"

TEST_SUITE_TESTS = dict(
    _is_valid_normal_version_number = is_valid_normal_version_number_test,
    _is_valid_prerelease_identifier = is_valid_prerelease_identifier_test,
    _is_valid_build_identifier = is_valid_build_identifier_test,
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
