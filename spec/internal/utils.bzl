"""utils.bzl"""

def isinstance(other, __classes__):
    if type(__classes__) not in ("tuple", "list"):
        __classes__ = [__classes__]

    other__class__ = getattr(other, "__class__", "")

    return any([
        other__class__ == __class__ or (
            # HACK for "subclasses"
            "." in __class__ and
            other__class__.startswith(__class__)
        )
        for __class__ in __classes__
    ])
