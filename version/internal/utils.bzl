"""
# version utils
"""

def _coerce(value, partial = False, wildcards = (), _fail = fail):
    if value in wildcards:
        return None
    elif value == None and partial:
        return None
    elif type(value) == "int":
        return value
    elif type(value) == "string":
        return int(value)
    else:
        return _fail("Can't coerce value: %s" % str(value))

def _has_leading_zero(value, allow_leading_zeroes = False):
    return (
        type(value) == "string" and
        len(value) >= 2 and
        value.isdigit() and
        value[0] == "0" and
        not allow_leading_zeroes
    )

def _is_(obj, __class__):
    return (
        type(obj) == "struct" and
        hasattr(obj, "__class__") and
        obj.__class__ == __class__
    )

def _is_digit(v):
    return (
        type(v) == "int" or
        (type(v) == "string" and v.isdigit())
    )

def _is_uint(v):
    return _is_digit(v) and int(v) >= 0

def _pad_with(padding, parts, max_length):
    padded = [padding] * max_length

    for idx, v in enumerate(parts):
        padded[idx] = v

    return tuple(padded) if type(parts) == "tuple" else parts

utils = struct(
    coerce = _coerce,
    has_leading_zero = _has_leading_zero,
    is_ = _is_,
    is_digit = _is_digit,
    is_uint = _is_uint,
    pad_with = _pad_with,
)
