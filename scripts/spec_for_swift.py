#!/usr/bin/env python3
"""The server's OpenAPI spec, in the form swift-openapi-generator reads (#6).

The server writes "an X, or null" the way JSON Schema 2020-12 means it:

    {"oneOf": [{"$ref": "#/components/schemas/X"}, {"type": "null"}]}

swift-openapi-generator does not support the `null` schema. It warns
`Schema "null" is not supported ... skipping`, and the generated type leaves
the whole PROPERTY out. Decoding still succeeds, so nothing fails, and the app
can never read the value: `Me.landing.club`, `MyBooking.lesson`, the rating
beside a level, and 24 more.

What the generator does read, checked against the version this package pins:

    {"$ref": "#/components/schemas/X", "type": ["object", "null"]}   -> X?
    {"type": ["object", "null"], "properties": {...}}                -> Payload?

The second is exactly the server's meaning. The first is not: under 2020-12 a
`$ref` applies beside its siblings, so it would refuse null. That is why the
server keeps `oneOf` and the rewrite happens here, on the copy the generator
reads, and never on the server's spec.

Anything nullable this cannot rewrite stops `make regenerate` and CI, naming
the path, rather than being dropped from the client again without a word.

    python3 scripts/spec_for_swift.py <server spec> <out>
"""

import json
import sys

NULL = {"type": "null"}


def for_swift(spec):
    """A rewritten copy of `spec`; raises ValueError listing what it cannot rewrite."""
    schemas = spec.get("components", {}).get("schemas", {})
    unhandled = []

    def nullable_type(t):
        return [*t, "null"] if isinstance(t, list) else [t, "null"]

    def rewrite(node, path):
        if isinstance(node, list):
            return [rewrite(v, f"{path}[{i}]") for i, v in enumerate(node)]
        if not isinstance(node, dict):
            return node
        node = {k: rewrite(v, f"{path}/{k}") for k, v in node.items()}
        for key in ("oneOf", "anyOf"):
            members = node.get(key)
            if not isinstance(members, list) or NULL not in members:
                continue
            others = [m for m in members if m != NULL]
            rest = {k: v for k, v in node.items() if k != key}
            if len(others) != 1:
                unhandled.append(f"{path}: {key} of {len(others)} schemas and null")
                continue
            (other,) = others
            if set(other) == {"$ref"}:
                target = schemas.get(other["$ref"].rsplit("/", 1)[-1], {})
                node = {**rest, "$ref": other["$ref"], "type": nullable_type(target.get("type", "object"))}
            elif "type" in other and "$ref" not in other and not set(other) & set(rest):
                node = {**rest, **other, "type": nullable_type(other["type"])}
            else:
                unhandled.append(f"{path}: {key} of null and {json.dumps(other)[:80]}")
        return node

    out = rewrite(spec, "")
    if unhandled:
        raise ValueError("Nullable schemas the Swift rewrite cannot handle:\n  " + "\n  ".join(unhandled))
    return out


def main(argv):
    if len(argv) != 3:
        sys.exit(__doc__.strip().splitlines()[-1].strip())
    with open(argv[1], encoding="utf-8") as f:
        spec = json.load(f)
    try:
        rewritten = for_swift(spec)
    except ValueError as e:
        sys.exit(str(e))
    with open(argv[2], "w", encoding="utf-8") as f:
        json.dump(rewritten, f, indent=2, ensure_ascii=False)
        f.write("\n")


if __name__ == "__main__":
    main(sys.argv)
