#!/usr/bin/env python3
# SPDX-License-Identifier: GPL-3.0-or-later
# Copyright (C) 2026 Bogner Chess
"""Derives the three engine-stage artifacts from ../v1/forty-move-game.json.

    python3 test/fixtures/analysis/stages/make_fixtures.py

The staged pipeline hands the app one artifact per stage instead of a finished
document, and `StageDocumentAssembler` puts a document back together from them.
These three files are what that assembler is tested against. They are derived,
not typed: every move, FEN, eval and variation in them is copied from the
vendored contract fixture, so they cannot describe a game that never happened.

The shapes come from chess-ai `main`, `src/chess_coaching/game_analysis/stages.py`
(`run_base_evaluation`, `run_base_classification`, `run_deep_evaluation`). Two
of them are the point of the exercise:

- a stage artifact's `nodes` are `Node.model_dump()` of the document's own node
  model, which is why a document can be assembled from them at all;
- stage 3 writes `engine` **flat** (`pass1_nodes`, `pass2_nodes`,
  `pass2_multipv`) where the document nests it, and the assembler is the one
  place that knows that.

Not pinned and not part of any contract: `../v1/` holds exactly the vendored
files, and these are ours. Run this again after re-vendoring and commit the
result.
"""

import copy
import json
from pathlib import Path

HERE = Path(__file__).resolve().parent
SOURCE = HERE.parent / "v1" / "forty-move-game.json"

ARTIFACT_VERSION = 1

#: Two plies the deep pass drops again, so that the stage-2 selection is
#: visibly a superset of the stage-3 moments rather than the same list twice.
#: Both are inaccuracies of the student in the vendored game.
EXTRA_SELECTED_PLIES = (14, 26)


def write(name, payload):
    path = HERE / name
    with path.open("w") as f:
        json.dump(payload, f, indent=2, ensure_ascii=False)
        f.write("\n")
    print("wrote", path.name)


def scan(doc, student_color):
    """A GameScan as `scan_to_dict` writes it: one entry per position."""
    nodes = doc["nodes"]
    positions = [
        {
            "fen": node["fen_before"],
            "eval_white": node["eval_before"],
            "best": None if node["best"] is None else {
                "san": node["best"]["san"],
                "uci": node["best"]["uci"],
                "eval": node["best"]["eval"],
            },
            "terminal": False,
        }
        for node in nodes
    ]
    positions.append(
        {
            "fen": nodes[-1]["fen_after"],
            "eval_white": nodes[-1]["eval_after"],
            "best": None,
            "terminal": True,
        }
    )
    return {
        "game": {
            "moves_san": [n["san"] for n in nodes],
            "moves_uci": [n["uci"] for n in nodes],
            "start_fen": doc["game"]["start_fen"],
            "result": doc["game"]["result"],
        },
        "positions": positions,
        "book": [n["classification"] == "book" for n in nodes],
        "opening_name": "Queen's Gambit Declined",
        "engine_calls": len(positions),
    }


def base_evaluation(doc, student_color):
    """Stage 1: a node per ply, no variations, nothing marked critical yet."""
    nodes = []
    for node in doc["nodes"]:
        stage_node = copy.deepcopy(node)
        stage_node["variations"] = []
        stage_node["is_critical"] = False
        stage_node["comment_ids"] = []
        nodes.append(stage_node)
    human = {
        str(node["ply"]): {
            "move_probs": [{"san": node["san"], "p": node["human"]["played_prob"]}],
            "win_prob": None,
            "source": "maia3-5m",
        }
        for node in doc["nodes"]
        if node.get("human")
    }
    return {
        "artifact_version": ARTIFACT_VERSION,
        "stage": "base_evaluation",
        "student_color": student_color,
        "white_rating": 1290,
        "black_rating": 1340,
        "scan": scan(doc, student_color),
        "nodes": nodes,
        "human": {"predictions": human, "peer_gap": {}, "available": True},
        "engine_calls": len(doc["nodes"]) + 1,
    }


def base_classification(doc):
    """Stage 2: the plies worth a closer look, a superset of stage 3's."""
    by_ply = {node["ply"]: node for node in doc["nodes"]}
    comment_type = {c["ply"]: c["type"] for c in doc["comments"]}
    selected = sorted(
        [n["ply"] for n in doc["nodes"] if n["is_critical"]]
        + list(EXTRA_SELECTED_PLIES)
    )
    selections = []
    for ply in selected:
        node = by_ply[ply]
        kind = comment_type.get(ply, "critical_moment")
        selections.append(
            {
                "ply": ply,
                "kind": kind,
                "score": node["win_pct_loss"],
                "reason": node["classification"]
                if kind == "critical_moment"
                else "only_move",
            }
        )
    return {
        "artifact_version": ARTIFACT_VERSION,
        "stage": "base_classification",
        "selections": selections,
        "sharpness": {},
    }


def peer_line(node):
    """A peer line out of an existing alternative: minor 5's new variation kind.

    The vendored fixtures are minor 5 but happen to contain no `peer_line`, and
    the app has to show one without mistaking it for a recommendation. The moves
    are the alternative's, so the line is still real chess from the fixture.
    """
    source = next(
        (v for v in node["variations"] if v["kind"] == "alternative"), None
    )
    if source is None:
        return None
    line = copy.deepcopy(source)
    line["id"] = source["id"].replace("-alt", "-peer")
    line["kind"] = "peer_line"
    line["source"] = "human_model"
    line["elo"] = 1300
    line["human_prob"] = 0.21
    return line


def deep_evaluation(doc, student_color):
    """Stage 3: the full nodes, accuracy, and a **flat** engine block."""
    nodes = copy.deepcopy(doc["nodes"])
    for node in nodes:
        node["comment_ids"] = []
        if node["is_critical"]:
            line = peer_line(node)
            if line is not None:
                node["variations"].append(line)
    moments = [
        {
            "ply": node["ply"],
            "kind": next(
                (c["type"] for c in doc["comments"] if c["ply"] == node["ply"]),
                "critical_moment",
            ),
            "phase": "middlegame" if node["ply"] > 20 else "opening",
            "moves_before_san": [n["san"] for n in doc["nodes"][: node["ply"] - 1]][-4:],
            "motifs": [],
            "material_balance": 0,
            "peer_move_san": None,
            "peer_move_prob": None,
            "selection_score": node["win_pct_loss"],
        }
        for node in doc["nodes"]
        if node["is_critical"]
    ]
    engine = doc["engine"]
    return {
        "artifact_version": ARTIFACT_VERSION,
        "stage": "deep_evaluation",
        "context": {
            "language": doc["language"],
            "student_color": student_color,
            "rating_band": doc["perspective"]["rating_band"],
            "result": doc["game"]["result"],
            "ply_count": doc["game"]["ply_count"],
            "opening_name": "Queen's Gambit Declined",
        },
        "nodes": nodes,
        "moments": moments,
        # The plies stage 2 picked that did not hold up in the deep pass.
        "dropped": list(EXTRA_SELECTED_PLIES),
        "accuracy": doc["accuracy"],
        "engine": {
            "name": engine["name"],
            "pass1_nodes": engine["pass1"]["nodes"],
            "pass2_nodes": engine["pass2"]["nodes"],
            "pass2_multipv": engine["pass2"]["multipv"],
            "human_model": engine["human_model"],
        },
        "engine_calls": 96,
    }


def main():
    doc = json.loads(SOURCE.read_text())
    student_color = doc["perspective"]["color"]
    write("base-evaluation.json", base_evaluation(doc, student_color))
    write("base-classification.json", base_classification(doc))
    write("deep-evaluation.json", deep_evaluation(doc, student_color))


if __name__ == "__main__":
    main()
