"""
# `Clauses`

Internal framework for building and evaluating logical expressions (clauses)
over version constraints.

This module defines a flexible clause system for version matching, supporting
constant matchers (`Always`, `Never`), comparison-based constraints (`Range`)
and logical composition (`AllOf`, `AnyOf`).

Clauses can be evaluated against versions (`match(version)`), simplified and/or
logically combined with `and`/`or` operators,

The typical use case is parsing and evaluating complex version requirement
expressions in package managers, version resolution tooling, build systems,
etc.

## Exposed types

* `clauses.Always`: *always* matches any version.
* `clauses.Never`: *never* matches any version.
* `clauses.Range`: matches versions according to version-aware comparison
  operators (`==`, `!=`, `<`, `>`, etc).
* `clauses.AllOf`: matches if *all* nested clauses match.
* `clauses.AnyOf`: matches if *any* nested clause matches.

Each `clause` has the following methods:
* `.match(version)`: checks if the clause matches a given version.
* `.and_()` and `.or_()`: logical composition of clauses.
* `.simplify()`: reduces nested structures.
* `.repr()` / `.pretty()`: stringified representations for debugging.

> [!NOTE]
> This module is intended for internal use and is NOT part of a public or
> stable API.
"""

load("//version:versions.bzl", Versions = "versions")

def _isinstance(other, __classes__):
    if type(__classes__) not in ("tuple", "list"):
        __classes__ = [__classes__]

    other__class__ = getattr(other, "__class__", "")

    return any([
        other__class__ == __class__ or (
            # HACK for Matcher subclasses
            "." in __class__ and
            other__class__.startswith(__class__)
        )
        for __class__ in __classes__
    ])

# Clause

__CLASS__CLAUSE = "Clause"

def _clause_new(self_dict, _fail = fail):
    base = dict(
        __class__ = __CLASS__CLAUSE,
        and_ = lambda other: _fail("NotImplemented"),
        or_ = lambda other: _fail("NotImplemented"),
        eq = lambda other: _fail("NotImplemented"),
        match = lambda version: _fail("NotImplemented"),
    )

    self = struct(**base)

    base |= dict(
        simplify = lambda: self,
        repr = lambda: repr(self),
        ne = lambda other: not self.eq(other),
    )

    self = struct(**base)

    base |= dict(
        to_str = lambda: self.repr(),
        pretty = lambda: self.repr(),
    )

    self_dict = base | self_dict

    self = struct(**self_dict)

    base |= dict(
        prettyprint = lambda: "\n" + self.pretty().replace("\t", "    "),
    )

    self_dict = base | self_dict

    return struct(**self_dict)

clause = struct(
    new = _clause_new,
)

# AllOf / AnyOf

__CLASS__ALLOF = "AllOf"
__CLASS__ANYOF = "AnyOf"

def _allof_anyof_new(__class__, clauses_, _fail = fail):
    def __stack_recurse__(self, leaf_f, node_f):
        stack = [(self, [], 0)]  # stack (node, children_results, depth)
        results = {}  # maps nodes to their node_f result

        __MAX_ITERATIONS__ = 2 << 31 - 2

        for i in range(__MAX_ITERATIONS__):  # while true
            if not stack:
                break

            if i + 1 == __MAX_ITERATIONS__:
                fail("__stack_recurse__: __MAX_ITERATIONS__")

            node, children_results, depth = stack.pop()

            if node in results:  # skip if already processed
                continue

            sub_results = []
            pending = False

            for c in node.clauses:
                if c in results:
                    sub_results.append(results[c])  # use the already computed value
                elif _isinstance(c, (__CLASS__ANYOF, __CLASS__ALLOF)):
                    stack.append((node, children_results, depth))  # re-push current node
                    stack.append((c, [], depth + 1))  # process child first
                    pending = True
                else:
                    sub_results.append(leaf_f(depth, c))

            if pending:
                continue  # defer formatting until children are processed

            results[node] = node_f(depth, node, sub_results)

            if stack:
                stack[-1][1].append(results[node])  # add to parent's list

        return results[self]

    def repr(self):
        def leaf_f(_, clause):
            return clause.repr()

        def result_f(_, node, sub_results):
            return "%s(%s)" % (node.__class__, ", ".join(sub_results))

        return __stack_recurse__(self, leaf_f, result_f)

    def pretty(self):
        def leaf_f(depth, clause):
            indent = "\t" * (depth + 1)
            return "%s%s" % (indent, clause.repr())

        def result_f(depth, node, sub_results):
            indent = "\t" * depth
            return "{}{}(\n{},\n{})".format(
                indent,
                node.__class__,
                ",\n".join(sub_results),
                indent,
            )

        return __stack_recurse__(self, leaf_f, result_f)

    def eq(self, other):
        return (
            _isinstance(other, self.__class__) and
            self.repr() == other.repr()
        )

    def match(self, version):
        def leaf_f(_, clause):
            return clause.match(version)

        def result_f(_, node, sub_results):
            if _isinstance(node, __CLASS__ALLOF):
                return all(sub_results)
            else:
                return any(sub_results)

        return __stack_recurse__(self, leaf_f, result_f)

    def simplify(self):
        def leaf_f(_, clause):
            return clause.simplify()

        def result_f(_, clause, sub_results):
            results = {c: r for c, r in zip(clause.clauses, sub_results)}

            merged = {}

            for c in clause.clauses:
                simplified = results[c]

                if _isinstance(simplified, self.__class__):
                    merged |= {c.repr(): c for c in simplified.clauses}
                elif (
                    _isinstance(self, __CLASS__ALLOF) and
                    _isinstance(simplified, __CLASS__ALWAYS)
                ):
                    continue
                elif (
                    _isinstance(self, __CLASS__ANYOF) and
                    _isinstance(simplified, __CLASS__NEVER)
                ):
                    continue
                else:
                    merged[simplified.repr()] = simplified

            merged = merged.values()

            if len(merged) == 1:
                return merged.pop()
            elif self.__class__ == __CLASS__ALLOF:
                return allof.new(*merged)
            else:
                return anyof.new(*merged)

        return __stack_recurse__(self, leaf_f, result_f)

    def _allof_and(self, other):
        if _isinstance(other, __CLASS__ALLOF):
            allof_clauses = list(self.clauses) + list(other.clauses)
        elif _isinstance(other, (__CLASS__ANYOF, __CLASS__MATCHER)):
            allof_clauses = list(self.clauses) + [other]
        else:
            return _fail("NotImplemented")

        return allof.new(*allof_clauses)

    def _anyof_and(self, other):
        if _isinstance(other, __CLASS__ALLOF):
            return other.and_(self)
        elif _isinstance(other, (__CLASS__ANYOF, __CLASS__MATCHER)):
            return allof.new(self, other)
        else:
            return _fail("NotImplemented")

    def and_(self, other):
        if _isinstance(self, __CLASS__ALLOF):
            return _allof_and(self, other)
        else:
            return _anyof_and(self, other)

    def _allof_or(self, other):
        if _isinstance(other, __CLASS__ANYOF):
            return other.or_(self)
        elif _isinstance(other, __CLASS__ALLOF):
            return anyof.new(self, other)
        elif _isinstance(other, __CLASS__MATCHER):
            return anyof.new(self, allof.new(other))
        else:
            return _fail("NotImplemented")

    def _anyof_or(self, other):
        if _isinstance(other, __CLASS__ANYOF):
            anyof_clauses = list(self.clauses) + list(other.clauses)
        elif _isinstance(other, (__CLASS__ALLOF, __CLASS__MATCHER)):
            anyof_clauses = list(self.clauses) + [other]
        else:
            return _fail("NotImplemented")

        return anyof.new(*anyof_clauses)

    def or_(self, other):
        if _isinstance(self, __CLASS__ALLOF):
            return _allof_or(self, other)
        else:
            return _anyof_or(self, other)

    # de-duping clauses
    clauses_dict = {c.repr(): c for c in clauses_}
    clauses_ = clauses_dict.values()

    if len(clauses_) == 1:
        return clauses_[0]

    self_dict = dict(
        __class__ = __class__,
        # NOTE:
        # Using tuple so the struct can be hashed, which is
        # needed when nesting AnyOf / AllOf clauses
        clauses = tuple(clauses_),
    )

    self = struct(**self_dict)

    self_dict |= dict(
        repr = lambda: repr(self),
        to_str = lambda: repr(self),
        pretty = lambda: pretty(self),
        eq = lambda other: eq(self, other),
        match = lambda version: match(self, version),
        simplify = lambda: simplify(self),
    )

    self = struct(**self_dict)

    self_dict |= dict(
        and_ = lambda other: and_(self, other),
        or_ = lambda other: or_(self, other),
    )

    return clause.new(self_dict, _fail = _fail)

def _allof_new(*clauses_, _fail = fail):
    return _allof_anyof_new(__CLASS__ALLOF, clauses_, _fail = _fail)

def _anyof_new(*clauses_, _fail = fail):
    return _allof_anyof_new(__CLASS__ANYOF, clauses_, _fail = _fail)

allof = struct(
    new = _allof_new,
)

anyof = struct(
    new = _anyof_new,
)

# Matcher

_MATCHER = "Matcher"
__CLASS__MATCHER = "%s." % _MATCHER

def _matcher_new(self_dict, _fail = fail):
    def and_(other):
        if _isinstance(other, __CLASS__ALLOF):
            return other.and_(self)
        elif _isinstance(other, (__CLASS__ANYOF, __CLASS__MATCHER)):
            return allof.new(self, other)
        else:
            return _fail("NotImplemented")

    def or_(other):
        if _isinstance(other, __CLASS__ANYOF):
            return other.or_(self)
        elif _isinstance(other, (__CLASS__ALLOF, __CLASS__MATCHER)):
            return anyof.new(self, other)
        else:
            return _fail("NotImplemented")

    self = struct(**self_dict)

    base = dict(
        and_ = and_,
        or_ = or_,
    )

    self_dict = base | self_dict

    self_dict["__class__"] = "%s.%s" % (_MATCHER, self_dict["__class__"])

    self = clause.new(self_dict)

    return self

matcher = struct(
    new = _matcher_new,
)

# Always / Never

__CLASS__ALWAYS = "Always"
__CLASS__NEVER = "Never"

def _always_new(_fail = fail):
    self_dict = dict(
        __class__ = __CLASS__ALWAYS,
        repr = lambda: "%s()" % __CLASS__ALWAYS,
        match = lambda version: True,
        and_ = lambda other: other,
    )

    self = struct(**self_dict)

    self_dict |= dict(
        eq = lambda other: _isinstance(other, self.__class__),
        or_ = lambda other: self,
    )

    return matcher.new(self_dict, _fail = _fail)

def _never_new(_fail = fail):
    self_dict = dict(
        __class__ = __CLASS__NEVER,
        repr = lambda: "%s()" % __CLASS__NEVER,
        match = lambda version: False,
        or_ = lambda other: other,
    )

    self = struct(**self_dict)

    self_dict |= dict(
        eq = lambda other: _isinstance(other, self.__class__),
        and_ = lambda other: self,
    )

    return matcher.new(self_dict, _fail = _fail)

always = struct(
    new = _always_new,
)

never = struct(
    new = _never_new,
)

# Range

__CLASS__RANGE = "Range"

def _range_new(
        operator,
        target,
        cls_name = Versions.VERSIONS.SEMVER,
        prerelease_policy = None,
        build_policy = None,
        _fail = fail):
    def _same_at(v1, v2, level):
        return v1.truncate(level).eq(v2.truncate(level))

    def _match_eq(version):
        if self.build_policy == range_.BUILD_STRICT:
            return (
                _same_at(self.target, version, "prerelease") and
                version.build == self.target.build
            )
        return version.eq(self.target)

    def _match_ne(version):
        if self.build_policy == range_.BUILD_STRICT:
            return not (
                _same_at(self.target, version, "prerelease") and
                version.build == self.target.build
            )

        if (
            version.prerelease and
            self.prerelease_policy == range_.PRERELEASE_NATURAL and
            _same_at(self.target, version, "patch") and
            not self.target.prerelease
        ):
            return False

        return version.ne(self.target)

    def _match_lt(version):
        if (
            version.prerelease and
            self.prerelease_policy == range_.PRERELEASE_NATURAL and
            _same_at(self.target, version, "patch") and
            not self.target.prerelease
        ):
            return False

        return version.lt(self.target)

    def match(version):
        version = cls.parse(version)

        if self.build_policy != range_.BUILD_STRICT:
            version = version.truncate("prerelease")

        if version.prerelease:
            if (
                self.prerelease_policy == range_.PRERELEASE_SAMEPATCH and
                not _same_at(self.target, version, "patch")
            ):
                return False

        matchers = {
            range_.OP_EQ: _match_eq,
            range_.OP_NE: _match_ne,
            range_.OP_LT: _match_lt,
            range_.OP_LE: lambda version: version.le(self.target),
            range_.OP_GT: lambda version: version.gt(self.target),
            range_.OP_GE: lambda version: version.ge(self.target),
        }

        if self.operator not in matchers:
            return _fail("Unknown operator: %s" % self.operator)

        return matchers[self.operator](version)

    def eq(other):
        return (
            _isinstance(other, self.__class__) and
            self.operator == other.operator and
            self.target.to_str() == other.target.to_str() and
            self.prerelease_policy == other.prerelease_policy
        )

    def to_str():
        return "%s%s" % (self.operator, self.target.to_str())

    def repr():
        policy_part = []

        if self.prerelease_policy != range_.PRERELEASE_NATURAL:
            policy_part.append("prerelease_policy=%r" % self.prerelease_policy)

        if self.build_policy != range_.BUILD_IMPLICIT:
            policy_part.append("build_policy=%r" % self.build_policy)

        policy_part_str = ", ".join(policy_part)

        return "%s(%r, %r%s)" % (
            __CLASS__RANGE,
            self.operator,
            self.target.to_str(),
            ", %s" % policy_part_str if policy_part_str else "",
        )

    cls = Versions.get_version_class(cls_name, _fail = _fail)

    if _fail != fail and type(cls) == "string":
        # testing: _fail returned an error string
        return cls

    target = cls.parse(target)

    prerelease_policy = prerelease_policy or range_.PRERELEASE_NATURAL
    build_policy = build_policy or range_.BUILD_IMPLICIT

    if target.build:
        build_policy = range_.BUILD_STRICT

    if target.build and operator not in (range_.OP_EQ, range_.OP_NE):
        msg = "Invalid range '%s%s': build numbers have no ordering."
        return _fail(msg % (operator, target.to_str()))

    self_dict = dict(
        __class__ = __CLASS__RANGE,
        operator = operator,
        target = target,
        prerelease_policy = prerelease_policy,
        build_policy = build_policy,
        to_str = to_str,
        repr = repr,
        match = match,
        eq = eq,
    )

    self = matcher.new(self_dict, _fail = _fail)

    return self

range_ = struct(
    new = _range_new,
    # --- operators ---
    OP_EQ = "==",
    OP_NE = "!=",
    OP_LT = "<",
    OP_LE = "<=",
    OP_GT = ">",
    OP_GE = ">=",
    # --- prerelease_policies ---
    # <1.2.3 matches 1.2.3-a1
    PRERELEASE_ALWAYS = "always",
    # <1.2.3 does not match 1.2.3-a1
    PRERELEASE_NATURAL = "natural",
    # 1.2.3-a1 is only considered if target == 1.2.3-xxx
    PRERELEASE_SAMEPATCH = "same-patch",
    # --- build_policies ---
    # 1.2.3 matches 1.2.3+*
    BUILD_IMPLICIT = "implicit",
    # 1.2.3 matches only 1.2.3, not 1.2.3+4
    BUILD_STRICT = "strict",
)

# Clauses

clauses = struct(
    Always = always,
    Never = never,
    AllOf = allof,
    AnyOf = anyof,
    Range = range_,
    isinstance = _isinstance,
    __test__ = struct(
        _clause_new = _clause_new,
    ),
)
