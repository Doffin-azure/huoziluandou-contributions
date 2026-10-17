"""Fetch the sample's CC0 materials from Poly Haven, with provenance and MD5 checks."""
from concurrent.futures import ThreadPoolExecutor
from pathlib import Path
import hashlib
import json
import urllib.request

ROOT = Path(__file__).resolve().parents[3]
DEST = ROOT / "assets/title/courtyard/materials"
HEADERS = {"User-Agent": "HuoziCourtyardSample/1.0 (CC0 game art study)"}


def request(url):
    return urllib.request.urlopen(urllib.request.Request(url, headers=HEADERS), timeout=60)


def metadata(asset):
    with request("https://api.polyhaven.com/files/" + asset) as response:
        return json.load(response)


def download(job):
    asset, kind, record = job
    suffix = Path(record["url"]).suffix
    path = DEST / f"{asset}_{kind}{suffix}"
    if not path.exists() or hashlib.md5(path.read_bytes()).hexdigest() != record["md5"]:
        with request(record["url"]) as response:
            content = response.read()
        assert hashlib.md5(content).hexdigest() == record["md5"], record["url"]
        path.write_bytes(content)
    print(f"{path.name}: {path.stat().st_size} bytes", flush=True)
    return dict(asset=asset, kind=kind, file=path.name, **record)


if __name__ == "__main__":
    DEST.mkdir(parents=True, exist_ok=True)
    jobs = []
    for asset in ["weathered_planks", "slate_floor", "white_plaster_rough_01", "roof_slates_02"]:
        records = metadata(asset)
        for kind in ["Diffuse", "nor_gl", "Rough"]:
            if kind in records:
                jobs.append((asset, kind.lower(), records[kind]["1k"]["jpg"]))
    sky = metadata("overcast_soil_puresky")["hdri"]["1k"]["hdr"]
    jobs.append(("overcast_soil_puresky", "sky", sky))
    with ThreadPoolExecutor(max_workers=4) as pool:
        files = list(pool.map(download, jobs))
    (DEST / "sources.json").write_text(json.dumps({
        "license": "CC0-1.0", "license_url": "https://polyhaven.com/license",
        "retrieved": "2026-10-16", "resolution": "1k", "files": files,
        "source_pages": ["https://polyhaven.com/a/" + name for name in sorted({j[0] for j in jobs})]
    }, ensure_ascii=False, indent=2), encoding="utf-8")
