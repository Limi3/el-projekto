#!/usr/bin/env python3
"""Generate a Rojo-compatible sourcemap.json from a project file (subset of Rojo's rules).

Rojo isn't installable in every environment; luau-lsp only needs the sourcemap to resolve
`script.Parent.X` requires and instance types. Rules implemented: $className, $path (dirs, init
files, .server/.client/.luau suffixes). When Rojo is available, prefer:
    rojo sourcemap preview-b.project.json -o sourcemap.json
"""
import json, os, re, sys

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", "..", ".."))

def file_node(path, name=None):
    base = os.path.basename(path)
    m = re.match(r"^(.*?)(\.server|\.client)?\.luau?$", base)
    nm = name or m.group(1)
    kind = m.group(2)
    cls = "Script" if kind == ".server" else "LocalScript" if kind == ".client" else "ModuleScript"
    return {"name": nm, "className": cls, "filePaths": [os.path.relpath(path, ROOT)]}

def dir_node(path, name):
    init = None
    cls = "Folder"
    for cand, c in (("init.server.luau", "Script"), ("init.client.luau", "LocalScript"), ("init.luau", "ModuleScript")):
        if os.path.exists(os.path.join(path, cand)):
            init, cls = cand, c
            break
    node = {"name": name, "className": cls, "children": []}
    if init:
        node["filePaths"] = [os.path.relpath(os.path.join(path, init), ROOT)]
    for entry in sorted(os.listdir(path)):
        full = os.path.join(path, entry)
        if entry.startswith(".") or entry == init:
            continue
        if os.path.isdir(full):
            node["children"].append(dir_node(full, entry))
        elif re.search(r"\.luau?$", entry):
            node["children"].append(file_node(full))
    return node

def walk(name, spec):
    if "$path" in spec:
        p = os.path.join(ROOT, spec["$path"])
        if os.path.isdir(p):
            node = dir_node(p, name)
        else:
            node = file_node(p, name)
    else:
        node = {"name": name, "className": spec.get("$className", "Folder"), "children": []}
    for k, v in spec.items():
        if k.startswith("$"):
            continue
        node.setdefault("children", []).append(walk(k, v))
    return node

project = json.load(open(os.path.join(ROOT, sys.argv[1] if len(sys.argv) > 1 else "preview-b.project.json")))
tree = walk(project["name"], project["tree"])
json.dump(tree, open(os.path.join(ROOT, "sourcemap.json"), "w"), indent=1)
print("wrote sourcemap.json")
