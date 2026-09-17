#!/usr/bin/env python3
"""ACP autopilot for GitHub Actions: extract -> seed -> render -> verify.

Fixes the three things that make `python3 -m acp.cli run` exit 0 with no video:
  1. `run` with no --limit/--idea/--job is a documented no-op (limit defaults to 0).
  2. A fresh checkout has an empty queue, and `trends --persist` can legitimately
     persist ZERO ideas (single-word trends are filtered, and DEDUP_DAYS=30 skips
     anything already seen), so the queue can still be empty afterwards.
  3. With no keys, stage 2 (LLM) and stage 3a (footage) fail, so nothing renders.

This script guarantees a non-empty queue, runs every job to `rendered`, and exits
non-zero if no .mp4 was produced - no more green runs with an empty artifact.
"""
from __future__ import annotations

import json
import os
import shutil
import subprocess
import sys
import time
import zipfile
from pathlib import Path

WS = Path(os.environ.get("GITHUB_WORKSPACE") or ".").resolve()
WANT = max(1, int(os.environ.get("PIPELINE_LIMIT") or 2))
UNTIL = os.environ.get("PIPELINE_UNTIL", "rendered")

# Evergreen last-resort ideas. Used only when discovery yields nothing, so the
# pipeline can never idle. Rotated by day so consecutive runs differ.
FALLBACK_IDEAS = [
    "Three habits that quietly kill small business cash flow",
    "The pricing mistake that keeps freelancers underpaid",
    "Why most side projects die in week three",
    "One spreadsheet habit that saves an hour every day",
    "The hidden cost of saying yes to every client",
    "How to spot a bad business deal in sixty seconds",
    "The two numbers every small business should track weekly",
]


def say(msg: str) -> None:
    print(msg, flush=True)


def gh(msg: str, kind: str = "warning") -> None:
    print(f"::{kind}::{msg}", flush=True)


# --------------------------------------------------------------- 1. environment
def set_env() -> None:
    """Keyless defaults so the first run can only fail for a real reason.
    Anything you set in the workflow `env:` block wins (setdefault)."""
    os.environ.setdefault("PYTHONPATH", str(WS))
    os.environ.setdefault("WORK_DIR", str(WS / "work"))
    os.environ.setdefault("FONTS_DIR", str(WS / "fonts"))
    os.environ.setdefault("TTS_PROVIDER", "edge")
    os.environ.setdefault("REQUIRE_APPROVAL", "false")   # -> render lands in 'approved'
    os.environ.setdefault("AUTO_PUBLISH", "false")       # -> never touch a platform API
    os.environ.setdefault("MIN_GAP_MINUTES", "0")
    os.environ.setdefault("DAILY_BUDGET_USD", "5")
    os.environ.setdefault("IDEAS_PER_RUN", str(WANT))
    os.environ.setdefault("TARGET_SECONDS", "26")
    os.environ.setdefault("VIDEO_W", "1080")
    os.environ.setdefault("VIDEO_H", "1920")
    os.environ.setdefault("X264_PRESET", "veryfast")
    os.environ.setdefault("PYTHONUNBUFFERED", "1")

    # --- Gemini (Google AI Studio) --------------------------------------------
    # acp/llm.py has no native Gemini branch: it only knows 'anthropic', 'echo' and
    # OpenAI-shaped /chat/completions. Google serves an OpenAI-compatible endpoint,
    # so pointing LLM_BASE_URL at it is all Gemini needs - plus copying the key into
    # LLM_API_KEY, because config.py only reads LLM_API_KEY / OPENAI_API_KEY.
    gem = os.environ.get("GEMINI_API_KEY") or os.environ.get("GOOGLE_API_KEY") or ""
    if os.environ.get("LLM_PROVIDER", "").lower() in ("gemini", "google", "googleai", "google-ai-studio"):
        os.environ["LLM_PROVIDER"] = "gemini"        # not in the json_object list -> no response_format
        os.environ.setdefault("LLM_BASE_URL", "https://generativelanguage.googleapis.com/v1beta/openai")
        os.environ.setdefault("LLM_MODEL", "gemini-2.5-flash")
        # 2.5-flash spends output tokens on hidden thinking; 1400 can return an empty
        # message and then "no JSON object in model output". Give it room.
        os.environ.setdefault("LLM_MAX_OUTPUT_TOKENS", "8192")
        if gem and not os.environ.get("LLM_API_KEY"):
            os.environ["LLM_API_KEY"] = gem
        os.environ.pop("OPENAI_API_KEY", None)       # never let a dead OpenAI key win
        if not os.environ.get("LLM_API_KEY"):
            gh("LLM_PROVIDER=gemini but no GEMINI_API_KEY secret - add it under "
               "Settings -> Secrets and variables -> Actions, or the run falls back to the offline writer")
    elif gem and not (os.environ.get("LLM_API_KEY") or os.environ.get("OPENAI_API_KEY")):
        os.environ.update(LLM_PROVIDER="gemini", LLM_API_KEY=gem,
                          LLM_BASE_URL="https://generativelanguage.googleapis.com/v1beta/openai")
        os.environ.setdefault("LLM_MODEL", "gemini-2.5-flash")
        os.environ.setdefault("LLM_MAX_OUTPUT_TOKENS", "8192")

    # Only fall back to the free/offline providers when no key is present.
    if not (os.environ.get("LLM_API_KEY") or os.environ.get("OPENAI_API_KEY")):
        os.environ.setdefault("LLM_PROVIDER", "echo")
    if not (os.environ.get("PEXELS_API_KEY") or os.environ.get("PIXABAY_API_KEY")):
        os.environ.setdefault("ASSET_PROVIDER", "mock")
    say(f"LLM: {os.environ.get('LLM_PROVIDER', 'openai')} model={os.environ.get('LLM_MODEL', 'gpt-4o-mini')} "
        f"key={'set' if os.environ.get('LLM_API_KEY') else '-'} | footage: {os.environ.get('ASSET_PROVIDER', 'pexels')}"
        f" | voice: {os.environ.get('TTS_PROVIDER')}")
    sys.path.insert(0, str(WS))


# --------------------------------------------------------------- 2. unpack zip
def unpack() -> None:
    if (WS / "acp" / "cli.py").is_file():
        say("acp/ already present in the workspace - no zip needed")
        return
    names = [n for n in os.environ.get("ACP_ZIP", "").split(":") if n]
    z = next((WS / n for n in names if (WS / n).is_file()), None)
    if z is None:
        cands = sorted(p for p in list(WS.glob("*.zip")) + list(WS.glob("*/*.zip"))
                       if "acp" in p.name.lower() and "/.git" not in str(p))
        z = cands[0] if cands else None
    if z is None:
        gh("no acp-pipeline*.zip at the repo root - upload it (Code -> Add file -> Upload files)", "error")
        sys.exit(3)

    out = Path("/tmp/acp-extract")
    shutil.rmtree(out, ignore_errors=True)
    try:
        with zipfile.ZipFile(z) as f:
            bad = f.testzip()
            if bad:
                gh(f"corrupt entry in {z.name}: {bad} - delete and re-upload the file", "error")
                sys.exit(4)
            entries = f.namelist()
            f.extractall(out)
    except zipfile.BadZipFile as e:
        gh(f"{z.name} is not a valid zip ({e}) - re-upload it", "error")
        sys.exit(4)

    # Copy the directory that CONTAINS acp/cli.py. Copying one level too deep is
    # exactly what produces a green extraction then ModuleNotFoundError: acp.
    cands = [out, *sorted(p for p in out.iterdir() if p.is_dir()),
             *sorted(p for p in out.glob("*/*") if p.is_dir())]
    root = next((d for d in cands if (d / "acp" / "cli.py").is_file()), None)
    if root is None:
        gh("extracted tree has no acp/cli.py - that zip is not the ACP pipeline", "error")
        sys.exit(5)
    for entry in sorted(root.iterdir()):
        if entry.name in (".git", ".github"):        # never overwrite this workflow
            continue
        dst = WS / entry.name
        if entry.is_dir():
            shutil.copytree(entry, dst, dirs_exist_ok=True)
        else:
            shutil.copy2(entry, dst)
    say(f"unpacked {len(entries)} entries from '{z.name}' (root {root})")
    if not (WS / "acp" / "cli.py").is_file():
        gh("acp/cli.py still missing after extraction", "error")
        sys.exit(5)


# --------------------------------------------------------------- 3. deps + font
def deps() -> None:
    pkgs = os.environ.get("PIP_PACKAGES", "requests edge-tts").split()
    r = subprocess.run([sys.executable, "-m", "pip", "install", "--quiet",
                        "--no-warn-script-location", *pkgs], capture_output=True, text=True)
    if r.returncode:
        gh(f"pip install failed: {(r.stderr or '')[-300:]}")


def fonts() -> None:
    """libass renders NOTHING when it cannot find a font: no error, just invisible
    captions. Guarantee one usable font file, or fall back to a system family."""
    fd = Path(os.environ["FONTS_DIR"])
    fd.mkdir(parents=True, exist_ok=True)
    have = list(fd.glob("*.ttf")) + list(fd.glob("*.otf")) + list(fd.glob("*.ttc"))
    if not have:
        try:  # Anton is the condensed display font the caption sizing assumes
            import urllib.request
            url = "https://github.com/google/fonts/raw/main/ofl/anton/Anton-Regular.ttf"
            req = urllib.request.Request(url, headers={"User-Agent": "acp-ci"})
            with urllib.request.urlopen(req, timeout=30) as r:  # noqa: S310
                data = r.read()
            if data[:4] in (b"\x00\x01\x00\x00", b"OTTO", b"true"):
                (fd / "Anton-Regular.ttf").write_bytes(data)
                have = [fd / "Anton-Regular.ttf"]
                os.environ["CAPTION_FONT"] = "Anton"
        except Exception as e:  # noqa: BLE001
            gh(f"font download skipped ({str(e)[:80]}) - using a system font")
    if not have:
        for src in Path("/usr/share/fonts").rglob("DejaVuSans-Bold.ttf"):
            shutil.copy2(src, fd / src.name)
            have = [fd / src.name]
            break
        os.environ["CAPTION_FONT"] = os.environ.get("CAPTION_FONT_FALLBACK", "DejaVu Sans")
    os.environ.setdefault("CAPTION_FONT", "Anton" if any(p.name.startswith("Anton") for p in have) else "DejaVu Sans")
    say(f"fonts: {[p.name for p in have] or 'none (system fontconfig only)'} -> CAPTION_FONT={os.environ['CAPTION_FONT']}")


# --------------------------------------------------------------- 4. seed queue
def seed(p, want: int) -> list[int]:
    """Return job ids to work on, guaranteeing at least `want` of them.

    Order of preference: jobs already mid-pipeline (a previous run crashed) ->
    queued 'new' jobs -> PIPELINE_IDEA -> live trend discovery -> evergreen list.
    """
    resumable = [j["id"] for st in ("captioned", "voiced", "assets", "scripted")
                 for j in p.db.list_jobs(st, 50)]
    ids = [j["id"] for j in p.db.list_jobs("new", 200)]
    if resumable:
        say(f"resuming {len(resumable)} job(s) left mid-pipeline: {resumable}")
    if ids:
        say(f"queue already holds {len(ids)} job(s) in state 'new': {ids[:10]}")

    manual = [x.strip() for x in (os.environ.get("PIPELINE_IDEA") or "").replace("\n", ";").split(";") if x.strip()]
    for idea in manual:
        ids.append(p.db.create_job(idea=idea, source="manual", score=100))
    if manual:
        say(f"seeded {len(manual)} manual idea(s) from PIPELINE_IDEA")

    need = want - len(ids) - len(resumable)
    if need > 0:
        try:
            from acp.stages.discovery import discover
            items = discover(limit=need)
            new = p.create_from_ideas(items)
            ids += new
            say(f"discovery seeded {len(new)} job(s): {[i.get('title', '')[:48] for i in items]}")
        except Exception as e:  # noqa: BLE001 - a blocked feed must not stop the run
            gh(f"trend discovery unusable ({type(e).__name__}: {str(e)[:140]}) - using the evergreen list")

    need = want - len(ids) - len(resumable)
    if need > 0:
        # Direct create_job: bypasses the `seen` dedup table and the discovery
        # filters, so this branch can never come back empty.
        start = int(time.strftime("%j")) + int(os.environ.get("GITHUB_RUN_NUMBER") or 0)
        for k in range(need):
            idea = FALLBACK_IDEAS[(start + k) % len(FALLBACK_IDEAS)]
            ids.append(p.db.create_job(idea=idea, source="evergreen", score=50))
        say(f"evergreen fallback seeded {need} job(s)")
    return resumable + ids


# --------------------------------------------------------------- 5. run + retry
def rewind(store, jid: int) -> None:
    """Reset a failed job to its last completed state (same rule as `acp retry`)."""
    pl = store.payload(jid)
    back = "new"
    for state, key in (("voiced", "voice"), ("assets", "assets"), ("scripted", "script")):
        if pl.get(key):
            back = state
            break
    if pl.get("render"):
        back = "rendered"
    store.update(jid, back, error=None, attempts=0)


LLM_SIGNS = ("llmerror", "insufficient_quota", "credit_balance", "http 429", "http 401", "http 403",
             "http 400", "no json object", "script rejected", "rate limit", "quota", "resource_exhausted")


def _degrade(cfg, kind: str) -> str:
    """Swap one broken provider for its keyless equivalent, in-process."""
    if kind == "llm":
        os.environ["LLM_PROVIDER"] = "echo"
        if cfg._settings:
            cfg._settings.llm_provider = "echo"
        return "LLM unusable (quota/auth/JSON) - retrying this job with the offline 'echo' writer"
    os.environ["ASSET_PROVIDER"] = "mock"
    if cfg._settings:
        cfg._settings.asset_provider = "mock"
    return "footage stage failed - retrying this job with ASSET_PROVIDER=mock"


def drive(p, ids: list[int]) -> dict:
    import acp.config as cfg

    done, failed, degraded = [], [], []
    for jid in ids:
        for attempt in (1, 2, 3):
            try:
                p.run_job(jid, until=UNTIL)
                job = p.db.get(jid)
                if job["state"] == "new":
                    gh(f"job {jid} did not advance: {job.get('error') or 'budget/attempt guard'}")
                    failed.append((jid, job.get("error") or "did not advance"))
                    break
                done.append(jid)
                say(f"job {jid}: {job['state']}  cost ${job.get('cost_usd') or 0:.4f}")
                break
            except Exception as e:  # noqa: BLE001
                err = f"{type(e).__name__}: {e}"
                low = err.lower()
                say(f"job {jid}: FAILED {err[:300]}")
                # Never let one dead API end the run: degrade that stage and retry.
                st = cfg._settings
                kind = None
                if any(sign in low for sign in LLM_SIGNS) and getattr(st, "llm_provider", "echo") != "echo":
                    kind = "llm"
                elif ("footage" in low or "clip" in low) and getattr(st, "asset_provider", "mock") != "mock":
                    kind = "assets"
                if attempt < 3 and kind:
                    gh(_degrade(cfg, kind))
                    degraded.append(kind)
                    rewind(p.db, jid)
                    continue
                failed.append((jid, err[:400]))
                break
    return {"done": done, "failed": failed, "degraded": sorted(set(degraded))}


# --------------------------------------------------------------- 6. verify
def verify(p, res: dict) -> int:
    work = Path(os.environ["WORK_DIR"])
    vids = sorted(work.glob("job_*/final.mp4"))
    out = WS / "videos"
    out.mkdir(exist_ok=True)
    lines = []
    for v in vids:
        job = v.parent.name
        qc = {}
        try:
            qc = json.loads((v.parent / "qc.json").read_text())
        except Exception:  # noqa: BLE001
            pass
        dst = out / f"{job}_{os.environ.get('GITHUB_RUN_NUMBER', '0')}.mp4"
        if not dst.exists():
            try:
                os.link(v, dst)
            except OSError:
                shutil.copy2(v, dst)
        lines.append(f"| {job} | {qc.get('duration', '?')}s | {qc.get('width')}x{qc.get('height')} | "
                     f"{qc.get('size_mb', round(v.stat().st_size / 1e6, 2))} MB | "
                     f"{'; '.join(qc.get('warnings') or []) or 'clean'} |")
    say("\n== queue ==")
    say(json.dumps(p.status(), indent=1))
    say(f"\nDONE: {len(vids)} video(s) in {work} (also copied to videos/)")
    for v in vids:
        say(f"   {v.relative_to(WS)}  {v.stat().st_size} bytes")

    summary = os.environ.get("GITHUB_STEP_SUMMARY")
    if summary:
        with open(summary, "a") as fh:
            fh.write(f"## ACP run: {len(vids)} video(s)\n\n"
                     f"- providers: `{os.environ.get('LLM_PROVIDER', 'openai')}` LLM / "
                     f"`{os.environ.get('ASSET_PROVIDER', 'pexels')}` footage / "
                     f"`{os.environ.get('TTS_PROVIDER')}` voice\n"
                     f"- jobs advanced: {res['done']}\n")
            if res.get("degraded"):
                fh.write(f"- degraded mid-run (a provider failed): {res['degraded']}\n")
            if res["failed"]:
                fh.write(f"- failed: {res['failed']}\n")
            if lines:
                fh.write("\n| job | duration | size | file | QC |\n|---|---|---|---|---|\n" + "\n".join(lines) + "\n")
    for jid, err in res["failed"]:
        gh(f"job {jid}: {err}")
    if not vids:
        gh("no final.mp4 produced - see the job errors above", "error")
        return 1
    return 0


def main() -> int:
    set_env()
    unpack()
    deps()
    fonts()
    say(f"workspace={WS}  want={WANT} job(s)  until={UNTIL}")
    rc = subprocess.run([sys.executable, "-m", "acp.cli", "selftest"], cwd=WS).returncode
    if rc:
        gh(f"selftest exited {rc}", "error")
        return rc
    from acp.orchestrate import Pipeline

    p = Pipeline()
    say(f"db={p.s.db_path}  work={p.s.work_dir}")
    ids = seed(p, WANT)
    say(f"working on job ids: {ids}")
    return verify(p, drive(p, ids))


if __name__ == "__main__":
    raise SystemExit(main())
