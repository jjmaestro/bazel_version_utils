"""
# `SYNTAX.SIMPLE` version requirement specification

This syntax is a natural and easy requirement specification somewhat inspired
by Python's [PEP 440] (e.g. `>=0.1.1,<0.3.0`). This is the default.

## Structure

This syntax is a port of [`python-semanticversion`'s `SimpleSpec`]. The syntax
uses the following rules:

* A specification expression is a list of clauses separated by a comma (`,`)
* A version is matched by an expression if, and only if, it matches *all*
  clauses in the expression
* A clause of `*` matches every valid version

### Equality clauses

* A clause of `==0.1.2` will match version `0.1.2` and any version
  differing only through its build number (`0.1.2+b42` matches).
* A clause of `==0.1.2+b42` will only match that specific version:
  `0.1.2+b43` and `0.1.2` are excluded.
* A clause of `==0.1.2+` will only match that specific version: `0.1.2+b42`
  is excluded.
* A clause of `!=0.1.2` will prevent all versions with the same
  major/minor/patch combination: `0.1.2-rc.1` and `0.1.2+b42` are excluded'.
* A clause of `!=0.1.2-` will only prevent build variations of that version:
  `0.1.2-rc.1` is included, but not `0.1.2+b42`.
* A clause of `!=0.1.2+` will exclude only that exact version: `0.1.2-rc.1` and
  `0.1.2+b42` are included.
* Only a `==` or `!=` clause may contain build-level metadata: `==1.2.3+b42` is
  valid, `>=1.2.3+b42` isn't.

### Comparison clauses

* A clause of `<0.1.2` will match versions strictly below `0.1.2`, excluding
  prereleases of `0.1.2`: `0.1.2-rc.1` is excluded.
* A clause of `<0.1.2-` will match versions strictly below `0.1.2`, including
  prereleases of `0.1.2`: `0.1.2-rc.1` is included.
* A clause of `<0.1.2-rc.3` will match versions strictly below `0.1.2-rc.3`,
  including prereleases: `0.1.2-rc.2` is included.
* A clause of `<=XXX` will match versions that match `<XXX` or `==XXX`.
* A clause of `>0.1.2` will match versions strictly above `0.1.2`, including
  all prereleases of `0.1.3`.
* A clause of `>0.1.2-rc.3` will match versions strictly above `0.1.2-rc.3`,
  including matching prereleases of `0.1.2`: `0.1.2-rc.10` is included.
* A clause of `>=XXX` will match versions that match `>XXX` or `==XXX`.

### Wildcards

* A clause of `==0.1.*` is equivalent to `>=0.1.0,<0.2.0`.
* A clause of `>=0.1.*` is equivalent to `>=0.1.0`.
* A clause of `==1.*` or `==1.*.*` is equivalent to `>=1.0.0,<2.0.0`.
* A clause of `>=1.*` or `>=1.*.*` is equivalent to `>=1.0.0`.
* A clause of `==*` maps to `>=0.0.0`.
* A clause of `>=*` maps to `>=0.0.0`.

### Extensions

Additionally, it supports extensions from specific packaging platforms:

PyPI-style `compatible release clauses`_:
* `~=2.2` means "Any release between `2.2.0` and `3.0.0`".
* `~=1.4.5` means "Any release between `1.4.5` and `1.5.0`".

NPM-style specs:
* `~1.2.3` means "Any release between `1.2.3` and `1.3.0`".
* `^1.3.4` means "Any release between `1.3.4` and `2.0.0`".


[PEP 440]: https://peps.python.org/pep-0440/
[`python-semanticversion`'s `SimpleSpec`]: https://python-semanticversion.readthedocs.io/en/latest/reference.html#semantic_version.SimpleSpec
[`Versions.VERSIONS`]: ../../../version/versions.bzl
"""

load("//version:versions.bzl", Versions = "versions")
load(":clauses.bzl", Always = "always", Range = "range_")

def _make_operators(operators, op_aliases = None):
    operators = operators.values()
    operators += (op_aliases or {}).keys()

    # NOTE:
    # parsing the expression requires the operators to be ordered by
    # operator length
    return sorted(operators, key = lambda x: (len(x), x), reverse = True)

def _has_op_with_spaces(block, ops):
    """
    Check if there's more than one operator separated by spaces.

    These are invalid blocks that need special detection to avoid
    turning them into valid blocks by normalizing the spaces in them
    (e.g. ' > = 1.0.0' could turn into '>= 1.0.0' after normalize)
    """
    chars = block.strip().elems()

    for i, c1 in enumerate(chars):
        if c1 == " ":
            continue

        for op in ops:
            if len(op) < 2:
                continue

            # Build a fragment (a non-space chars up-to the length of
            # the operator)
            fragment = ""
            non_space_chars = 0
            for c2 in chars[i:]:
                if non_space_chars == len(op):
                    break

                fragment += c2

                if c2 != " ":
                    non_space_chars += 1

            # Check if the fragment is a potential conflict (a fragment
            # that's not an operator but it would become one if we
            # remove the spaces)
            if fragment != op and fragment.replace(" ", "") == op:
                return True

    return False

def _parse_block(self, expression, cls, npm_mode = False, _fail = fail):
    def _target(**fields):
        valid_fields = {
            field: value
            for field, value in fields.items()
            if cls.has(field)
        }

        return cls.new(**valid_fields)

    if not expression:
        return _fail("Empty spec")

    wildcards = ["*", "x", "X"]

    if expression[0].isdigit() or expression[0] in wildcards:
        op = ""
        version = expression
    else:
        op = None
        version = None

        # NOTE: candidate_operators exclude the "empty" alias (EQ)
        candidate_operators = [o for o in self.OPERATORS if len(o) > 0]
        for candidate_op in candidate_operators:
            if expression.startswith(candidate_op):
                op = candidate_op
                version = expression[len(op):]
                break

        if op == None:
            return _fail("Can't find a valid spec operator")

    if op not in self.OPERATORS:
        return _fail("Invalid spec expression operator: %s" % op)

    op = self.OP_ALIASES.get(op, op)

    parts = cls.parse_spec(version, wildcards, _fail = _fail)

    if _fail != fail and type(parts) == "string":
        # testing: _fail returned an error string
        return parts

    major, minor, patch, prerelease, build = parts

    if major == None:  # wildcards
        if op not in (self.OPS.EQ, self.OPS.GE):
            return _fail("Invalid spec expression: %r" % expression)

        target = _target(major = 0, minor = 0, patch = 0)
    elif minor == None:
        target = _target(major = major, minor = 0, patch = 0)
    elif patch == None:
        target = _target(major = major, minor = minor, patch = 0)
    else:
        target = _target(
            major = major,
            minor = minor,
            patch = patch,
            prerelease = prerelease,
            build = build,
        )

    if major == None and npm_mode:
        op = self.OPS.GE

    if not npm_mode and build and op not in (self.OPS.EQ, self.OPS.NE):
        return _fail("Invalid spec expression: %r" % expression)

    assert_is_not_none = \
        lambda v: fail("v == None and it shouldn't be") if v == None else None

    if op == self.OPS.CARET and npm_mode:
        if target.has("patch"):
            target_truncated = target.truncate("patch")
        else:
            target_truncated = target.truncate("minor")

        if target.major:
            # ^1.2.4 => >=1.2.4 <2.0.0 ; ^1.x => >=1.0.0 <2.0.0
            high = target_truncated.bump("major")
        elif target.minor:
            # ^0.1.2 => >=0.1.2 <0.2.0
            high = target_truncated.bump("minor")
        elif minor == None:
            # ^0.x => >=0.0.0 <1.0.0
            high = target_truncated.bump("major")
        elif patch == None:
            # ^0.2.x => >=0.2.0 <0.3.0
            high = target_truncated.bump("minor")
        else:
            # ^0.0.1 => >=0.0.1 <0.0.2 / ^16.1 => >=16.1 <16.2
            if target.has("patch"):
                high = target_truncated.bump("patch")
            else:
                high = target_truncated.bump("minor")

        return [
            self._range(Range.OP_GE, target),
            self._range(Range.OP_LT, high),
        ]

    elif op == self.OPS.CARET and not npm_mode:
        # Accept anything with the same most-significant digit
        if target.major:
            high = target.bump("major")
        elif target.minor:
            high = target.bump("minor")
        else:
            high = target.bump("patch")

        return [
            self._range(Range.OP_GE, target),
            self._range(Range.OP_LT, high),
        ]

    elif op == self.OPS.TILDE:
        assert_is_not_none(major)

        # Accept any higher patch in the same minor
        # Might go higher if the initial version was a partial
        if minor == None:  # ~1.x => >=1.0.0 <2.0.0
            high = target.bump("major")
        else:
            # ~1.2.x => >=1.2.0 <1.3.0; ~1.2.3 => >=1.2.3 <1.3.0
            high = target.bump("minor")
        return [self._range(Range.OP_GE, target), self._range(Range.OP_LT, high)]

    elif op == self.OPS.EQ:
        if major == None:
            return [
                self._range(Range.OP_GE, target),
            ]
        elif minor == None:
            return [
                self._range(Range.OP_GE, target),
                self._range(Range.OP_LT, target.bump("major")),
            ]
        elif patch == None:
            return [
                self._range(Range.OP_GE, target),
                self._range(Range.OP_LT, target.bump("minor")),
            ]
        elif build == () and expression[-1] == "+" and not npm_mode:
            return [
                self._range(Range.OP_EQ, target, build_policy = Range.BUILD_STRICT),
            ]
        else:
            return [self._range(Range.OP_EQ, target)]

    elif op == self.OPS.GT:
        assert_is_not_none(major)

        if minor == None:  # >1.x => >=2.0
            return [self._range(Range.OP_GE, target.bump("major"))]
        elif patch == None:  # >1.2.x => >=1.3.0
            return [self._range(Range.OP_GE, target.bump("minor"))]
        else:
            return [self._range(Range.OP_GT, target)]

    elif op == self.OPS.GE:
        return [self._range(Range.OP_GE, target)]

    elif op == self.OPS.LT:
        assert_is_not_none(major)

        if prerelease == () and not npm_mode:  # <1.2.3-
            return [
                self._range(
                    Range.OP_LT,
                    target,
                    prerelease_policy = Range.PRERELEASE_ALWAYS,
                ),
            ]

        return [self._range(Range.OP_LT, target)]

    elif op == self.OPS.LE:
        assert_is_not_none(major)

        if minor == None:  # <=1.x => <2.0.0
            return [self._range(Range.OP_LT, target.bump("major"))]
        elif patch == None:  # <=1.2.x => <1.3.0
            return [self._range(Range.OP_LT, target.bump("minor"))]
        else:
            return [self._range(Range.OP_LE, target)]

    elif not npm_mode and op == self.OPS.COMPATIBLE:
        assert_is_not_none(major)

        # ~1 is 1.0.0..2.0.0; ~=2.2 is 2.2.0..3.0.0; ~=1.4.5 is 1.4.5..1.5.0
        if minor == None or patch == None:
            # we got a partial version
            high = target.bump("major")
        else:
            high = target.bump("minor")
        return [self._range(Range.OP_GE, target), self._range(Range.OP_LT, high)]

    elif not npm_mode and op == self.OPS.NE:
        assert_is_not_none(major)

        if minor == None:
            # !=1.x => <1.0.0 || >=2.0.0
            return [
                self._range(
                    Range.OP_LT,
                    target,
                ).or_(self._range(
                    Range.OP_GE,
                    target.bump("major"),
                )),
            ]
        elif patch == None:
            # !=1.2.x => <1.2.0 || >=1.3.0
            return [
                self._range(
                    Range.OP_LT,
                    target,
                ).or_(self._range(
                    Range.OP_GE,
                    target.bump("minor"),
                )),
            ]
        elif prerelease == () and expression[-1] == "-":
            # !=1.2.3-
            return [
                self._range(
                    Range.OP_NE,
                    target,
                    prerelease_policy = Range.PRERELEASE_ALWAYS,
                ),
            ]
        elif build == () and expression[-1] == "+":
            # !=1.2.3+ or !=1.2.3-a2+
            return [
                self._range(
                    Range.OP_NE,
                    target,
                    build_policy = Range.BUILD_STRICT,
                ),
            ]
        else:
            return [self._range(Range.OP_NE, target)]
    else:
        return fail("Should never execute this statement")

def _simple_parser_new(cls_name = Versions.VERSIONS.SEMVER, _fail = fail):
    """
    Constructs a `NpmParser` `struct`.

    The `struct` has a `parse()` method that can parse a "simple-style" version
    requirement specification (a port of [`python-semanticversion`'s
    `SimpleSpec`]). It will return a [`Clause`] that can then be matched
    against a given version to test if the version satisfies the requirement
    specification with `match(version)`.

    > [!NOTE]
    > This parser is internal and meant to be used in [`Spec`].

    [`Clause`]: clauses.md
    [`Spec`]: ../spec.md

    Args:
        cls_name (string): the version class to use (one of
            [`Versions.VERSIONS`]).
        _fail (function): **[TESTING]** Mock of the `fail()` function.

    Returns:
        A `NpmParser` `struct`.
    """

    def normalize(expression):
        def normalize_block(block):
            if not " " in block:
                return block

            operators = [op for op in self.OPERATORS if op]

            if _has_op_with_spaces(block, operators):
                return block

            return "".join([
                sub_block.strip()
                for sub_block in block.split(" ")
            ])

        return JOINER.join([
            normalize_block(block)
            for block in expression.split(JOINER)
        ])

    def parse(expression):
        expression = normalize(expression)

        clause = Always.new()

        for block in expression.split(JOINER):
            clauses = _parse_block(self, block, cls, _fail = _fail)

            if _fail != fail and type(clauses) == "string":
                # testing: _fail returned an error string
                return clauses

            if len(clauses) == 1:
                clause_ = clauses[0]
            elif len(clauses) == 2:
                clause_ = clauses[0].and_(clauses[1])
            else:
                fail("Should never be here")

            clause = clause.and_(clause_)

        return clause

    def _range(operator, target, **kwargs):
        return Range.new(
            operator,
            target,
            cls_name = cls_name,
            **kwargs
        )

    cls = Versions.get_version_class(cls_name, _fail = _fail)

    if _fail != fail and type(cls) == "string":
        # testing: _fail returned an error string
        return cls

    JOINER = ","

    self = struct(
        __class__ = "SimpleParser",
        OPS = struct(**OPS),
        OP_ALIASES = OP_ALIASES,
        OPERATORS = _make_operators(OPS, OP_ALIASES),
        parse = parse,
        normalize = normalize,
        _range = _range,
    )

    return self

OPS = dict(
    LT = "<",
    LE = "<=",
    GE = ">=",
    GT = ">",
    EQ = "==",
    TILDE = "~",
    CARET = "^",
    NE = "!=",
    COMPATIBLE = "~=",
)

OP_ALIASES = {"": "==", "=": "=="}

simpleparser = struct(
    new = _simple_parser_new,
    OPS = struct(**OPS),
    OP_ALIASES = OP_ALIASES,
    __internal__ = struct(
        _parse_block = _parse_block,
        _make_operators = _make_operators,
        _has_op_with_spaces = _has_op_with_spaces,
    ),
)
