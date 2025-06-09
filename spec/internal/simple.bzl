"""
# `spec/internal/simple.bzl`

See [`docs/spec/internal/simple`]

[`docs/spec/internal/simple`]: ../../docs/spec/internal/simple.md
[`Version.SCHEME`]: ../../../version/version.bzl
"""

load("//version:version.bzl", Version = "version")
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

def _parse_block(self, expression, VersionScheme, npm_mode = False, _fail = fail):
    def _target(**fields):
        valid_fields = {
            field: value
            for field, value in fields.items()
            if VersionScheme.has(field)
        }

        return VersionScheme.new(**valid_fields)

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

    parts = VersionScheme.parse_spec(version, wildcards, _fail = _fail)

    if _fail != fail and type(parts) == "string":
        # testing: _fail returned an error string
        return parts

    major, minor, patch, prerelease, build = parts

    if major == None:  # wildcards
        if op not in (self.OP.EQ, self.OP.GE):
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
        op = self.OP.GE

    if not npm_mode and build and op not in (self.OP.EQ, self.OP.NE):
        return _fail("Invalid spec expression: %r" % expression)

    assert_is_not_none = \
        lambda v: fail("v == None and it shouldn't be") if v == None else None

    if op == self.OP.CARET and npm_mode:
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
            self._range(Range.OP.GE, target),
            self._range(Range.OP.LT, high),
        ]

    elif op == self.OP.CARET and not npm_mode:
        # Accept anything with the same most-significant digit
        if target.major:
            high = target.bump("major")
        elif target.minor:
            high = target.bump("minor")
        else:
            high = target.bump("patch")

        return [
            self._range(Range.OP.GE, target),
            self._range(Range.OP.LT, high),
        ]

    elif op == self.OP.TILDE:
        assert_is_not_none(major)

        # Accept any higher patch in the same minor
        # Might go higher if the initial version was a partial
        if minor == None:  # ~1.x => >=1.0.0 <2.0.0
            high = target.bump("major")
        else:
            # ~1.2.x => >=1.2.0 <1.3.0; ~1.2.3 => >=1.2.3 <1.3.0
            high = target.bump("minor")
        return [self._range(Range.OP.GE, target), self._range(Range.OP.LT, high)]

    elif op == self.OP.EQ:
        if major == None:
            return [
                self._range(Range.OP.GE, target),
            ]
        elif minor == None:
            return [
                self._range(Range.OP.GE, target),
                self._range(Range.OP.LT, target.bump("major")),
            ]
        elif patch == None:
            return [
                self._range(Range.OP.GE, target),
                self._range(Range.OP.LT, target.bump("minor")),
            ]
        elif build == () and expression[-1] == "+" and not npm_mode:
            return [
                self._range(Range.OP.EQ, target, build_policy = Range.BUILD.STRICT),
            ]
        elif npm_mode:
            return [self._range(Range.OP.EQ, target, build_policy = Range.BUILD.IMPLICIT)]
        else:
            return [self._range(Range.OP.EQ, target)]

    elif op == self.OP.GT:
        assert_is_not_none(major)

        if minor == None:  # >1.x => >=2.0
            return [self._range(Range.OP.GE, target.bump("major"))]
        elif patch == None:  # >1.2.x => >=1.3.0
            return [self._range(Range.OP.GE, target.bump("minor"))]
        else:
            return [self._range(Range.OP.GT, target)]

    elif op == self.OP.GE:
        return [self._range(Range.OP.GE, target)]

    elif op == self.OP.LT:
        assert_is_not_none(major)

        if prerelease == () and not npm_mode:  # <1.2.3-
            return [
                self._range(
                    Range.OP.LT,
                    target,
                    prerelease_policy = Range.PRERELEASE.ALWAYS,
                ),
            ]

        return [self._range(Range.OP.LT, target)]

    elif op == self.OP.LE:
        assert_is_not_none(major)

        if minor == None:  # <=1.x => <2.0.0
            return [self._range(Range.OP.LT, target.bump("major"))]
        elif patch == None:  # <=1.2.x => <1.3.0
            return [self._range(Range.OP.LT, target.bump("minor"))]
        else:
            return [self._range(Range.OP.LE, target)]

    elif not npm_mode and op == self.OP.COMPATIBLE:
        assert_is_not_none(major)

        # ~1 is 1.0.0..2.0.0; ~=2.2 is 2.2.0..3.0.0; ~=1.4.5 is 1.4.5..1.5.0
        if minor == None or patch == None:
            # we got a partial version
            high = target.bump("major")
        else:
            high = target.bump("minor")
        return [self._range(Range.OP.GE, target), self._range(Range.OP.LT, high)]

    elif not npm_mode and op == self.OP.NE:
        assert_is_not_none(major)

        if minor == None:
            # !=1.x => <1.0.0 || >=2.0.0
            return [
                self._range(
                    Range.OP.LT,
                    target,
                ).or_(self._range(
                    Range.OP.GE,
                    target.bump("major"),
                )),
            ]
        elif patch == None:
            # !=1.2.x => <1.2.0 || >=1.3.0
            return [
                self._range(
                    Range.OP.LT,
                    target,
                ).or_(self._range(
                    Range.OP.GE,
                    target.bump("minor"),
                )),
            ]
        elif prerelease == () and expression[-1] == "-":
            # !=1.2.3-
            return [
                self._range(
                    Range.OP.NE,
                    target,
                    prerelease_policy = Range.PRERELEASE.ALWAYS,
                ),
            ]
        elif build == () and expression[-1] == "+":
            # !=1.2.3+ or !=1.2.3-a2+
            return [
                self._range(
                    Range.OP.NE,
                    target,
                    build_policy = Range.BUILD.STRICT,
                ),
            ]
        else:
            return [self._range(Range.OP.NE, target)]
    else:
        return fail("Should never execute this statement")

def _simple_parser_new(version_scheme = Version.SCHEME.SEMVER, _fail = fail):
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
        version_scheme (string): the version scheme to use (one of
            [`Version.SCHEME`]).
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
            clauses = _parse_block(self, block, VersionScheme, _fail = _fail)

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
            version_scheme = version_scheme,
            **kwargs
        )

    # buildifier: disable=name-conventions
    VersionScheme = Version.new(version_scheme, _fail = _fail)

    if _fail != fail and type(VersionScheme) == "string":
        # testing: _fail returned an error string
        return VersionScheme

    JOINER = ","

    self = struct(
        __class__ = "SimpleParser",
        OP = OP,
        OP_ALIASES = OP_ALIASES,
        OPERATORS = _make_operators(_OP, OP_ALIASES),
        parse = parse,
        normalize = normalize,
        _range = _range,
    )

    return self

_OP = dict(
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
OP = struct(**_OP)

OP_ALIASES = {"": "==", "=": "=="}

simpleparser = struct(
    new = _simple_parser_new,
    OP = OP,
    OP_ALIASES = OP_ALIASES,
    __internal__ = struct(
        _parse_block = _parse_block,
        _make_operators = _make_operators,
        _has_op_with_spaces = _has_op_with_spaces,
    ),
)
