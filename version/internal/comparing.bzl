"""
# version comparing "trait"

- Comparable objects must have __class__, __cmp_key__ and __sort_key__
- Comparable objects __class__ must be the same
"""

load("//version/internal:utils.bzl", "utils")

PRECEDENCE = struct(
    HIGH = "high",
    LOW = "low",
)

__MAX_ITERATIONS__ = 2 << 31 - 2

def _make_precedence_key(components, precedence = PRECEDENCE.HIGH):
    # precedence:
    # 1     < 1.1 < 1.1.0 --> lower_precedence = -Inf
    # 1.1.0 < 1.1 < 1     --> higher_precedence = +Inf
    precedence = float("+Inf") if precedence == PRECEDENCE.HIGH else float("-Inf")

    # First, we add all the components to the stack in reverse,
    # marking them # as not processed
    processed = False
    stack = [(c, processed) for c in reversed(components)]

    # Then we add a list where each result will be added after being processed
    result_stack = [[]]

    # Now, we iterate the stack with a 'while stack:' equivalent for-loop
    for i in range(__MAX_ITERATIONS__):
        if i == __MAX_ITERATIONS__:
            fail("_make_precedence_key: __MAX_ITERATIONS__ reached")

        if not stack:
            break

        c, processed = stack.pop()

        if processed:
            # the last element in result_stack is the accumulated result
            # from the tuple/list, so we pop it and append it again after
            # converting it to a tuple
            precedence_key = result_stack.pop()
            result_stack[-1].append(tuple(precedence_key))

        elif type(c) in ("tuple", "list"):
            # append a marker to the stack so we know that we are processing
            # the results of a tuple/list
            stack.append((None, True))

            if len(c) == 0:
                c = (None,)

            # append the lis where we will accumulate the
            # results of the tuple/list
            result_stack.append([])

            # append the elements to the stack so we will process them
            # adding their results to the accumulator
            for item in reversed(c):
                stack.append((item, False))
        elif c == None:
            result_stack[-1].append((precedence,))
        elif utils.is_digit(c):
            result_stack[-1].append((0, int(c)))
        else:
            result_stack[-1].append((1, str(c)))

    return tuple(result_stack.pop())

def __is_comparable__(obj):
    return (
        hasattr(obj, "__is__") and
        hasattr(obj, "__cmp_key__") and
        hasattr(obj, "__sort_key__")
    )

def __eq__(self, other):
    return self.__cmp_key__ == other.__cmp_key__

def __lt__(self, other):
    return self.__cmp_key__ < other.__cmp_key__

def __ne__(self, other):
    return not __eq__(self, other)

def __gt__(self, other):
    return __lt__(other, self)

def __le__(self, other):
    return __lt__(self, other) or __eq__(self, other)

def __ge__(self, other):
    return __lt__(other, self) or __eq__(self, other)

def __cmp__(self, other):
    return int(__gt__(self, other)) - int(__lt__(self, other))

def __comparison_op__(self, other, op, _fail = fail):
    if not self.__is__(other):
        msg = "Can't compare different object types: %r (self) VS %r (other)"
        return _fail(msg % (self.__class__, other.__class__))

    if not __is_comparable__(self):
        return _fail("Objects are not Comparable")

    return op(self, other)

def _new(self_dict, _fail = fail):
    self = struct(**self_dict)

    self_dict |= dict(
        eq = lambda other: __comparison_op__(self, other, __eq__, _fail),
        lt = lambda other: __comparison_op__(self, other, __lt__, _fail),
        ne = lambda other: __comparison_op__(self, other, __ne__, _fail),
        le = lambda other: __comparison_op__(self, other, __le__, _fail),
        gt = lambda other: __comparison_op__(self, other, __gt__, _fail),
        ge = lambda other: __comparison_op__(self, other, __ge__, _fail),
        cmp = lambda other: __comparison_op__(self, other, __cmp__, _fail),
    )

    return self_dict

def _sorted(versions, reverse = False, _fail = fail):
    for idx, version in enumerate(versions):
        if not __is_comparable__(version):
            msg = "Can't sort objects without __cmp_key__: %d/%d"
            _fail(msg % (idx, len(versions)))

    return sorted(versions, key = lambda self: self.__sort_key__, reverse = reverse)

comparing = struct(
    new = _new,
    make_precedence_key = _make_precedence_key,
    sorted = _sorted,
)
