#!/usr/bin/env python3
# SPDX-License-Identifier: GPL-3.0-or-later
# Copyright (C) 2026 Bogner Chess
"""Derives the two hand-made forward-compatibility fixtures from ../v1/short-game.json.

Run it again after re-vendoring ../v1 (python3 make_fixtures.py) and commit the result.
All chess in the output is copied from the vendored fixture; nothing is typed by hand.
"""

import copy
import json
from pathlib import Path

HERE = Path(__file__).resolve().parent
SOURCE = HERE.parent / "v1" / "short-game.json"

UNKNOWN_TYPE_COMMENT_ID = "0b0f4c9e-7a53-4a0e-9d55-0c1f6f1b2a77"


def node(doc, ply):
    return doc["nodes"][ply - 1]


def comment_at(doc, ply):
    return next(c for c in doc["comments"] if c["ply"] == ply)


def with_unknowns(source):
    """Still major 1: everything a newer *minor* may add."""
    doc = copy.deepcopy(source)
    doc["schema_minor"] = 7

    # Unknown top-level keys and unknown keys in the envelope objects.
    doc["opening"] = {"eco": "B15", "name": "Caro-Kann Defence"}
    doc["x_experimental"] = [1, {"a": None}]
    doc["perspective"]["player_rating"] = 1130
    doc["engine"]["human_model"] = "maia3-blitz"
    doc["engine"]["pass3"] = {"nodes": 20000000, "multipv": 5}
    doc["game"]["termination"] = "checkmate"
    doc["accuracy"]["formula"] = "v2"

    # Extra fields inside every node, inside evals, best, human.
    for n in doc["nodes"]:
        n["clock_ms"] = 600000 - 4000 * n["ply"]
    node(doc, 10)["eval_before"]["depth"] = 24
    node(doc, 10)["best"]["rank"] = 1
    node(doc, 10)["human"]["entropy"] = 2.1

    # Unknown classification value.
    node(doc, 3)["classification"] = "brilliant"

    # Unknown variation kind (a copy of the best line, so the chess is real),
    # with extra fields in the variation and in its moves.
    plan = copy.deepcopy(node(doc, 12)["variations"][0])
    assert plan["id"] == "v12-best"
    plan["id"] = "v12-plan"
    plan["kind"] = "plan"
    plan["pv_depth"] = 31
    for m in plan["moves"]:
        m["nag"] = 0
    node(doc, 12)["variations"].append(plan)

    # Unknown theme, square role and arrow role; extra fields in a comment.
    c10 = comment_at(doc, 10)
    c10["theme"] = "zwischenzug"
    c10["squares"][0]["role"] = "outpost"
    c10["arrows"].append({"from": "c8", "to": "f5", "role": "plan", "style": "dashed"})
    c10["verdict"] = "mistake"
    c10["audio_url"] = None

    # A line reference to the variation of the unknown kind.
    comment_at(doc, 12)["lines"].append(
        {"variation_id": "v12-plan", "label": "Plan", "collapsed": True}
    )

    # Unknown verification status.
    comment_at(doc, 16)["verification"]["status"] = "human_reviewed"

    # A comment of an unknown type on a node that has no other comment.
    note = copy.deepcopy(c10)
    note.update(
        id=UNKNOWN_TYPE_COMMENT_ID,
        type="opening_note",
        ply=2,
        title="The Caro-Kann",
        text="A solid reply: c6 prepares d5 without blocking the bishop on c8.",
        theme="opening",
        squares=[],
        arrows=[],
        lines=[],
        moves_mentioned=["c6"],
    )
    doc["comments"].insert(0, note)
    node(doc, 2)["comment_ids"] = [UNKNOWN_TYPE_COMMENT_ID]

    # Unknown theme and an extra field in a lesson.
    doc["summary"]["lessons"][1]["theme"] = "time_management"
    doc["summary"]["lessons"][0]["drill_id"] = "drill-42"
    return doc


def v2_major(source):
    """A made-up major 2: the node shape changed in breaking ways."""
    doc = copy.deepcopy(source)
    doc["schema_version"] = 2
    doc["schema_minor"] = 0
    for n in doc["nodes"]:
        # New unit and nesting for evals, win percentages gone.
        n["eval"] = {
            "before": {"wp": round(n.pop("win_pct_before") / 100, 3)},
            "after": {"wp": round(n.pop("win_pct_after") / 100, 3)},
        }
        del n["eval_before"], n["eval_after"], n["win_pct_loss"]
        # A string became an object.
        n["classification"] = {"label": n["classification"], "score": 0.5}
        # `best` became a list, variations became compact strings.
        n["candidates"] = [] if n["best"] is None else [n["best"]["uci"]]
        del n["best"]
        n["lines"] = [
            {"id": v["id"], "pv": " ".join(m["uci"] for m in v["moves"])}
            for v in n.pop("variations")
        ]
        n["annotation_ids"] = n.pop("comment_ids")
    # Comments became a map of annotations with a different text shape.
    doc["annotations"] = {
        c["id"]: {"kind": c["type"], "ply": c["ply"], "body": [{"md": c["text"]}]}
        for c in doc.pop("comments")
    }
    return doc


def main():
    source = json.loads(SOURCE.read_text(encoding="utf-8"))
    for name, build in (("v1-with-unknowns.json", with_unknowns), ("v2-major.json", v2_major)):
        text = json.dumps(build(source), indent=2, ensure_ascii=False) + "\n"
        (HERE / name).write_text(text, encoding="utf-8")
        print(f"wrote {name}")


if __name__ == "__main__":
    main()
