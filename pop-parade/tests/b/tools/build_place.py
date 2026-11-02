#!/usr/bin/env python3
"""Build a Roblox place file (.rbxlx) from a Rojo project file, for Studio previews without Rojo.

    python3 tests/b/tools/build_place.py preview-b.project.json out/PopParade-PreviewB.rbxlx

Implements the subset of Rojo we use: $className, $path (folders, init.luau, *.server.luau,
*.client.luau, *.luau), nested tree nodes. Output is a build artifact (gitignored) for opening in
Studio; the source of truth stays the Luau files. Prefer `rojo build` when Rojo is installed.
"""
import json, os, re, sys
from xml.sax.saxutils import escape

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", "..", ".."))
_ref = [0]


def ref():
    _ref[0] += 1
    return "RBX%08X" % _ref[0]


def cdata(src):
    return "<![CDATA[" + src.replace("]]>", "]]]]><![CDATA[>") + "]]>"


def script_item(cls, name, path):
    with open(path, encoding="utf-8") as fh:
        src = fh.read()
    return (
        '<Item class="%s" referent="%s"><Properties><string name="Name">%s</string>'
        '<ProtectedString name="Source">%s</ProtectedString></Properties>' % (cls, ref(), escape(name), cdata(src))
    )


def file_item(path, name=None):
    base = os.path.basename(path)
    m = re.match(r"^(.*?)(\.server|\.client)?\.luau?$", base)
    nm = name or m.group(1)
    cls = {".server": "Script", ".client": "LocalScript"}.get(m.group(2), "ModuleScript")
    return script_item(cls, nm, path) + "</Item>"


def dir_item(path, name):
    init = None
    for cand, cls in (("init.server.luau", "Script"), ("init.client.luau", "LocalScript"), ("init.luau", "ModuleScript")):
        if os.path.exists(os.path.join(path, cand)):
            init = (cand, cls)
            break
    out = []
    if init:
        out.append(script_item(init[1], name, os.path.join(path, init[0])))
    else:
        out.append('<Item class="Folder" referent="%s"><Properties><string name="Name">%s</string></Properties>' % (ref(), escape(name)))
    for entry in sorted(os.listdir(path)):
        full = os.path.join(path, entry)
        if entry.startswith(".") or (init and entry == init[0]):
            continue
        if os.path.isdir(full):
            out.append(dir_item(full, entry))
        elif re.search(r"\.luau?$", entry):
            out.append(file_item(full))
    out.append("</Item>")
    return "".join(out)


def node(name, spec):
    if "$path" in spec:
        p = os.path.join(ROOT, spec["$path"])
        body = dir_item(p, name) if os.path.isdir(p) else file_item(p, name)
        # children declared alongside $path are appended inside the item
        extra = "".join(node(k, v) for k, v in spec.items() if not k.startswith("$"))
        return body[: -len("</Item>")] + extra + "</Item>" if extra else body
    cls = spec.get("$className", "Folder")
    props = '<string name="Name">%s</string>' % escape(name)
    # $properties subset: {"Enum": n} -> token, bool, number -> float, string
    for pname, val in spec.get("$properties", {}).items():
        if isinstance(val, dict) and "Enum" in val:
            props += '<token name="%s">%d</token>' % (pname, val["Enum"])
        elif isinstance(val, bool):
            props += '<bool name="%s">%s</bool>' % (pname, "true" if val else "false")
        elif isinstance(val, (int, float)):
            props += '<float name="%s">%s</float>' % (pname, val)
        else:
            props += '<string name="%s">%s</string>' % (pname, escape(str(val)))
    inner = "".join(node(k, v) for k, v in spec.items() if not k.startswith("$"))
    return '<Item class="%s" referent="%s"><Properties>%s</Properties>%s</Item>' % (cls, ref(), props, inner)


def main():
    proj = sys.argv[1] if len(sys.argv) > 1 else "preview-b.project.json"
    out = sys.argv[2] if len(sys.argv) > 2 else "build/PopParade-PreviewB.rbxlx"
    project = json.load(open(os.path.join(ROOT, proj)))
    tree = project["tree"]
    services = "".join(node(k, v) for k, v in tree.items() if not k.startswith("$"))
    xml = (
        '<roblox xmlns:xmime="http://www.w3.org/2005/05/xmlmime" '
        'xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" '
        'xsi:noNamespaceSchemaLocation="http://www.roblox.com/roblox.xsd" version="4">'
        + services
        + "</roblox>"
    )
    out_path = os.path.join(ROOT, out)
    os.makedirs(os.path.dirname(out_path), exist_ok=True)
    with open(out_path, "w", encoding="utf-8") as fh:
        fh.write(xml)
    print("wrote %s (%d instances)" % (out, _ref[0]))


main()
