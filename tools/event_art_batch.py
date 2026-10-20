#!/usr/bin/env python3
"""Batch-submit event-art prompts to a local ComfyUI instance.

Usage:
  python tools/event_art_batch.py --dry-run
  python tools/event_art_batch.py --only shefu
  python tools/event_art_batch.py --start 0 --limit 5

The workflow is the same one used for docs/art-concepts/2026-10-19-event-art-sample.
It produces a cutout PNG; the event screen will pick it up through the
assets/events/art_manifest.json fallback after the file exists.
"""
from __future__ import annotations

import argparse
import json
import time
import urllib.parse
import urllib.request
import uuid
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
PROMPTS = ROOT / "assets/events/prompts_batch_2026-10-19.json"
MANIFEST = ROOT / "assets/events/art_manifest.json"
WORKFLOW = ROOT / "docs/art-concepts/2026-10-19-event-art-sample/lantern_riddle_complete.api.json"


def request_json(url: str, payload: dict | None = None) -> dict:
    data = None if payload is None else json.dumps(payload).encode("utf-8")
    req = urllib.request.Request(url, data=data, headers={"Content-Type": "application/json"})
    with urllib.request.urlopen(req, timeout=30) as response:
        return json.loads(response.read().decode("utf-8"))


def build_workflow(template: dict, event: dict, common_style: str, common_negative: str) -> dict:
    workflow = json.loads(json.dumps(template))
    workflow["4"]["inputs"]["text"] = event["scene"] + "\n" + common_style
    workflow["5"]["inputs"]["text"] = event.get("negative", common_negative)
    workflow["7"]["inputs"]["seed"] = int(event["seed"])
    workflow["9"]["inputs"]["filename_prefix"] = f"lianziyu/event_{event['id']}_base"
    workflow["11"]["inputs"]["filename_prefix"] = f"lianziyu/event_{event['id']}_final"
    return workflow


def submit(event: dict, common_style: str, common_negative: str, server: str, dry_run: bool) -> Path | None:
    template = json.loads(WORKFLOW.read_text(encoding="utf-8"))
    workflow = build_workflow(template, event, common_style, common_negative)
    target = ROOT / event["file"]
    if dry_run:
        print(f"[dry-run] {event['id']} -> {target}")
        return None
    result = request_json(server + "/prompt", {"prompt": workflow, "client_id": uuid.uuid4().hex})
    prompt_id = result.get("prompt_id")
    if not prompt_id:
        raise RuntimeError(f"ComfyUI rejected {event['id']}: {result}")
    print(f"[queue] {event['id']} {prompt_id}")
    deadline = time.time() + 300
    history = {}
    while time.time() < deadline:
        history = request_json(server + f"/history/{prompt_id}")
        if prompt_id in history:
            break
        time.sleep(2)
    else:
        raise TimeoutError(f"ComfyUI timed out for {event['id']}")
    outputs = history[prompt_id].get("outputs", {})
    # Node 11 is the BiRefNet cutout SaveImage. Fall back to the last image.
    image = None
    for node_id in ("11", "9"):
        for item in outputs.get(node_id, {}).get("images", []):
            image = item
            break
        if image:
            break
    if image is None:
        raise RuntimeError(f"No output image for {event['id']}")
    query = urllib.parse.urlencode({
        "filename": image["filename"],
        "subfolder": image.get("subfolder", ""),
        "type": image.get("type", "output"),
    })
    with urllib.request.urlopen(server + "/view?" + query, timeout=60) as response:
        data = response.read()
    target.parent.mkdir(parents=True, exist_ok=True)
    target.write_bytes(data)
    print(f"[saved] {target} ({len(data)} bytes)")
    return target


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--server", default="http://127.0.0.1:8188")
    parser.add_argument("--only", default="")
    parser.add_argument("--start", type=int, default=0)
    parser.add_argument("--limit", type=int, default=0)
    parser.add_argument("--dry-run", action="store_true")
    args = parser.parse_args()
    prompt_data = json.loads(PROMPTS.read_text(encoding="utf-8"))
    events = prompt_data["events"]
    if args.only:
        events = [e for e in events if e["id"] == args.only]
    else:
        events = events[args.start:]
        if args.limit:
            events = events[:args.limit]
    if not events:
        raise SystemExit("No matching events. Check --only/--start/--limit.")
    for event in events:
        submit(event, prompt_data["style"], prompt_data["negative"], args.server, args.dry_run)


if __name__ == "__main__":
    main()
