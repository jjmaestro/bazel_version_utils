"""
# `spec/internal/npm.bzl`

See [`docs/spec/internal/npm`]

[`docs/spec/internal/npm`]: ../../docs/spec/internal/npm.md
"""

load("//version:semver.bzl", SemVer = "semver")
load(":clauses.bzl", AllOf = "allof", Never = "never", Range = "range_")
load(":simple.bzl", SimpleParser = "simpleparser")

def _parse_block(self, expr, _fail = fail):
    return SimpleParser.__internal__._parse_block(
        self,
        expr,
        npm_mode = True,
        _fail = _fail,
    )

def _npm_parser_new(_fail = fail):
    """
    Constructs a `NpmParser` `struct`.

    The `struct` has a `parse()` method that can parse an NPM-style version
    requirement specification. It will return a [`Clause`] that can then be
    matched against a given version to test if the version satisfies the
    requirement specification with `match(version)`.

    > [!NOTE]
    > This parser is internal and meant to be used in [`Spec`].

    [`Clause`]: clauses.md
    [`Spec`]: ../spec.md

    Args:
        _fail (function): **[TESTING]** Mock of the `fail()` function.

    Returns:
        A `NpmParser` `struct`.
    """

    def normalize(expression):
        def normalize_block(block):
            if not " " in block:
                return block

            operators = [op for op in self.OPERATORS if op]

            if SimpleParser.__internal__._has_op_with_spaces(block, operators):
                return block

            # First, split in sub-blocks with no spaces in them
            sub_blocks = [c for c in block.split(" ") if c]

            # Then, expand the sub-blocks splitting by non-empty operators
            expanded = []
            for sub_block in sub_blocks:
                matched = False
                for op in operators:
                    if not matched and op in sub_block:
                        matched = True
                        expanded += [p for p in sub_block.partition(op) if p]

                if not matched:
                    expanded.append(sub_block)

            # Then, create op-version blocks
            part_op, part_version = "", ""
            op_version_blocks = []
            for part in expanded:
                if part in operators:
                    part_op = part
                else:
                    part_version = part

                    op_version_blocks.append("%s%s" % (part_op, part_version))
                    part_op, part_version = "", ""

            # Finally, space-join the op-version blocks
            return " ".join(op_version_blocks)

        return (" %s " % JOINER).join([
            HYPHEN.join([
                normalize_block(block)
                for block in group.split(HYPHEN)
            ])
            for group in expression.split(JOINER)
        ])

    def parse(expression):
        expression = normalize(expression)

        result = Never.new()
        groups = expression.split(JOINER)

        for group in groups:
            group = group.strip()

            if not group:
                group = ">=0.0.0"

            if HYPHEN in group:
                low, high = group.split(HYPHEN, 2)
                blocks = [
                    "%s%s" % (op, bound)
                    for op, bound in zip((OP.GE, OP.LE), (low, high))
                ]
            else:
                blocks = group.split(" ")

            subclauses = []
            for block in blocks:
                clauses = _parse_block(self, block, _fail = _fail)

                if _fail != fail and type(clauses) == "string":
                    # testing: _fail returned an error string
                    return clauses

                subclauses.extend(clauses)

            prerelease_clauses = []
            non_prerel_clauses = []

            for clause in subclauses:
                if clause.target.prerelease:
                    prerelease_clauses.append(clause)

                    if clause.operator in (Range.OP.GT, Range.OP.GE):
                        r = Range.new(
                            operator = Range.OP.LT,
                            target = SemVer.new(
                                major = clause.target.major,
                                minor = clause.target.minor,
                                patch = clause.target.patch + 1,
                            ),
                            prerelease_policy = Range.PRERELEASE.ALWAYS,
                        )
                        prerelease_clauses.append(r)
                    elif clause.operator in (Range.OP.LT, Range.OP.LE):
                        r = Range.new(
                            operator = Range.OP.GE,
                            target = SemVer.new(
                                major = clause.target.major,
                                minor = clause.target.minor,
                                patch = 0,
                                prerelease = (),
                            ),
                            prerelease_policy = Range.PRERELEASE.ALWAYS,
                        )
                        prerelease_clauses.append(r)

                    r = self._range(
                        operator = clause.operator,
                        target = clause.target.truncate("patch"),
                    )
                    non_prerel_clauses.append(r)
                else:
                    non_prerel_clauses.append(clause)

            if prerelease_clauses:
                result = result.or_(AllOf.new(*prerelease_clauses))

            result = result.or_(AllOf.new(*non_prerel_clauses))

        return result

    def _range(operator, target):
        return Range.new(
            operator,
            target,
            prerelease_policy = Range.PRERELEASE.SAMEPATCH,
        )

    JOINER = "||"
    HYPHEN = " - "

    self = struct(
        __class__ = "NpmParser",
        OP = OP,
        OP_ALIASES = OP_ALIASES,
        OPERATORS = SimpleParser.__internal__._make_operators(_OP, OP_ALIASES),
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
    EQ = "=",
    TILDE = "~",
    CARET = "^",
)
OP = struct(**_OP)

OP_ALIASES = {"": "="}

npmparser = struct(
    new = _npm_parser_new,
    OP = OP,
    OP_ALIASES = OP_ALIASES,
)
