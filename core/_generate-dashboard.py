#!/usr/bin/env python3
"""
Sinapsis Dashboard Generator
────────────────────────────
Reads all Sinapsis data sources (instincts, passive rules, proposals,
activation logs, skills catalog, projects, operator state, observations)
and generates a self-contained HTML dashboard at _dashboard.html.

Called by: /dashboard-sinapsis command, sinapsis-linting scheduled task.
Deterministic — no LLM, no tokens spent.
"""
from __future__ import annotations
import json
import os
import re
import sys
from collections import Counter, defaultdict
from datetime import datetime, timezone, timedelta
from pathlib import Path

# Portable: resolve ~/.claude from $HOME. Override with SINAPSIS_HOME if set.
ROOT = Path(os.environ.get('SINAPSIS_HOME') or (Path.home() / '.claude'))
SKILLS = ROOT / 'skills'
HOMUNCULUS = ROOT / 'homunculus'
COMMANDS = ROOT / 'commands'
OUT = SKILLS / '_dashboard.html'
# Template lookup: sibling _dashboard-template.html if present (installed layout
# or repo layout), otherwise fall back to $SKILLS_DIR.
_script_dir = Path(__file__).parent
_sibling_tpl = _script_dir / '_dashboard-template.html'
TEMPLATE = _sibling_tpl if _sibling_tpl.exists() else SKILLS / '_dashboard-template.html'


def load_json(path: Path, default):
    try:
        return json.loads(path.read_text(encoding='utf-8'))
    except Exception:
        return default


def parse_iso(s: str | None):
    if not s:
        return None
    try:
        return datetime.fromisoformat(s.replace('Z', '+00:00'))
    except Exception:
        return None


def now_utc():
    return datetime.now(timezone.utc)


def days_ago(dt: datetime | None, ref: datetime | None = None):
    if not dt:
        return None
    ref = ref or now_utc()
    return (ref - dt).days


# ═══════════════════════════════════════════════════════════════════════════
# DATA COLLECTION
# ═══════════════════════════════════════════════════════════════════════════

def collect_instincts():
    idx = load_json(SKILLS / '_instincts-index.json', {'instincts': []})
    items = idx.get('instincts', [])
    now = now_utc()
    for i in items:
        i['_last_days'] = days_ago(parse_iso(i.get('last_triggered')), now)
        i['_first_days'] = days_ago(parse_iso(i.get('first_triggered')), now)
        i['_added_days'] = days_ago(parse_iso((i.get('added') or '') + 'T00:00:00Z'), now)
    return items


def collect_passive_log():
    """Returns dict of rule_id -> activation count, parsed from _passive.log."""
    log = SKILLS / '_passive.log'
    counts = Counter()
    if not log.exists():
        return counts
    try:
        for line in log.read_text(encoding='utf-8', errors='replace').splitlines():
            # Format varies; try to extract rule id from common patterns
            m = re.search(r'\|\s*([\w-]+)\s*\|', line)
            if m:
                counts[m.group(1)] += 1
    except Exception:
        pass
    return counts


def collect_instinct_log():
    """Parse _instinct.log for hour distribution + 21d activity heatmap."""
    log = SKILLS / '_instinct.log'
    hour_dist = [0] * 24
    day_activity = defaultdict(int)
    total = 0
    if not log.exists():
        return hour_dist, day_activity, 0
    try:
        lines = log.read_text(encoding='utf-8', errors='replace').splitlines()
        total = len(lines)
        for line in lines:
            # Format: "2026-03-31T07:21:31.481Z | Edit | instincts..."
            m = re.match(r'(\d{4}-\d{2}-\d{2})T(\d{2}):', line)
            if m:
                day, hour = m.group(1), int(m.group(2))
                hour_dist[hour] += 1
                day_activity[day] += 1
    except Exception:
        pass
    return hour_dist, day_activity, total


def collect_proposals():
    p = load_json(SKILLS / '_instinct-proposals.json', {'proposals': []})
    stats = Counter()
    by_type = Counter()
    for prop in p.get('proposals', []):
        stats[prop.get('status', 'pending')] += 1
        if prop.get('status') == 'pending':
            by_type[prop.get('type', 'unknown')] += 1
    return dict(stats), dict(by_type)


def collect_skills():
    cat = load_json(SKILLS / '_catalog.json', [])
    total = len(cat)
    stubs = sum(1 for s in cat if s.get('description', '').startswith('(auto-generated'))
    complete = total - stubs
    # Approximate 5 globals from CLAUDE.md
    globals_ = 5
    return total, globals_, complete - globals_, stubs


def collect_projects():
    proj = load_json(SKILLS / '_projects.json', {'projects': []})
    active = [p for p in proj.get('projects', []) if p.get('active')]
    total_obs = 0
    proj_obs = []
    if HOMUNCULUS.exists():
        proj_dir = HOMUNCULUS / 'projects'
        if proj_dir.exists():
            for d in proj_dir.iterdir():
                obs_file = d / 'observations.jsonl'
                if obs_file.exists():
                    try:
                        n = sum(1 for _ in obs_file.open('r', encoding='utf-8', errors='replace'))
                        total_obs += n
                        ctx = d / 'context.md'
                        name = d.name
                        if ctx.exists():
                            try:
                                for ln in ctx.read_text(encoding='utf-8').splitlines()[:5]:
                                    if 'Proyecto' in ln or 'proyecto' in ln:
                                        pass
                            except Exception:
                                pass
                        proj_obs.append((name, n))
                    except Exception:
                        pass
    proj_obs.sort(key=lambda x: -x[1])
    return len(active), total_obs, proj_obs[:18]


def collect_decisions():
    op = load_json(SKILLS / '_operator-state.json', {})
    decs = op.get('strategicDecisions', [])
    decs.sort(key=lambda d: d.get('date', ''), reverse=True)
    return decs


def collect_passive_rules():
    r = load_json(SKILLS / '_passive-rules.json', {'rules': []})
    return r.get('rules', [])


# ═══════════════════════════════════════════════════════════════════════════
# METRIC COMPUTATION
# ═══════════════════════════════════════════════════════════════════════════

def compute_metrics(instincts, pstats, ptypes, prules, passive_counts,
                    hour_dist, day_activity, total_acts,
                    skills_total, skills_globals, skills_complete, skills_stubs,
                    projects_active, observations_total, top_projects,
                    decisions):

    levels = Counter(i['level'] for i in instincts)
    domain_cnt = Counter(i.get('domain', '?') for i in instincts)
    origin_cnt = Counter(i.get('origin', 'unknown') for i in instincts)

    # Top 10 by occurrences
    top_instincts = sorted(
        [i for i in instincts if i.get('occurrences', 0) > 0],
        key=lambda x: -x.get('occurrences', 0)
    )[:10]

    # Dead instincts: occurrences == 0 OR last_triggered > 21 days
    dead = [
        {
            'id': i['id'],
            'trigger': i.get('trigger_pattern', ''),
            'age': i.get('_last_days') or i.get('_added_days') or 0,
            'reason': 'never_triggered' if i.get('occurrences', 0) == 0 else 'stale'
        }
        for i in instincts
        if i.get('occurrences', 0) == 0 or (i.get('_last_days') or 0) > 21
    ]
    dead.sort(key=lambda x: -x['age'])

    # Top passive rules (merge config + log counts)
    rules_with_counts = []
    for r in prules:
        rid = r.get('id', 'unknown')
        count = passive_counts.get(rid, 0)
        rules_with_counts.append({
            'id': rid,
            'count': count,
            'type': 'loud' if not r.get('silent', True) else 'silent',
            'priority': r.get('priority', 'medium')
        })
    rules_with_counts.sort(key=lambda x: -x['count'])
    top_rules = rules_with_counts[:10]

    # Timing: maturation averages
    added_dates = [parse_iso((i.get('added') or '') + 'T00:00:00Z') for i in instincts]
    first_tr = [parse_iso(i.get('first_triggered')) for i in instincts if i.get('first_triggered')]
    maturation_latency_days = []
    for i in instincts:
        a = parse_iso((i.get('added') or '') + 'T00:00:00Z')
        f = parse_iso(i.get('first_triggered'))
        if a and f:
            d = (f - a).days
            if 0 <= d <= 60:
                maturation_latency_days.append(d)
    avg_latency = round(sum(maturation_latency_days) / len(maturation_latency_days), 1) if maturation_latency_days else 0

    # Permanent age
    perm_ages = [i.get('_added_days') or 0 for i in instincts if i.get('level') == 'permanent']
    avg_perm_age = round(sum(perm_ages) / len(perm_ages)) if perm_ages else 0

    # Velocity: instincts created per week (last 4 weeks)
    now = now_utc()
    velocity_weeks = []
    for w in range(3, -1, -1):
        week_start = now - timedelta(days=(w + 1) * 7)
        week_end = now - timedelta(days=w * 7)
        cnt = sum(1 for a in added_dates if a and week_start <= a <= week_end)
        velocity_weeks.append(cnt)

    # Activity last 21 days (one value per day, oldest first)
    heatmap_21 = []
    for d in range(20, -1, -1):
        date = (now - timedelta(days=d)).strftime('%Y-%m-%d')
        heatmap_21.append(day_activity.get(date, 0))

    # Quantize heatmap to 0-4 for color classes
    max_heat = max(heatmap_21) if heatmap_21 else 1
    heatmap_q = [min(4, round(v / max_heat * 4)) if v > 0 else 0 for v in heatmap_21] if max_heat > 0 else [0] * 21

    # Ratios
    obs_per_instinct = round(observations_total / max(1, len([i for i in instincts if i.get('level') != 'draft']))) if instincts else 0
    pending = pstats.get('pending', 0)
    accepted = pstats.get('accepted', 0)
    discarded = pstats.get('discarded', 0)
    acceptance_rate = round(accepted / max(1, accepted + discarded) * 100) if (accepted + discarded) else 0

    return {
        'meta': {
            'generated_at': now.isoformat(timespec='seconds'),
            'date_display': now.strftime('%Y-%m-%d %H:%M'),
            'total_instincts': len(instincts),
            'permanent': levels.get('permanent', 0),
            'confirmed': levels.get('confirmed', 0),
            'draft': levels.get('draft', 0),
            'rules_total': len(prules),
            'rules_loud': sum(1 for r in rules_with_counts if r['type'] == 'loud'),
            'rules_silent': sum(1 for r in rules_with_counts if r['type'] == 'silent'),
            'skills_total': skills_total,
            'skills_globals': skills_globals,
            'skills_complete': skills_complete,
            'skills_stubs': skills_stubs,
            'projects_active': projects_active,
            'observations_total': observations_total,
            'total_activations': total_acts,
            'proposals_pending': pending,
            'proposals_accepted': accepted,
            'proposals_discarded': discarded,
            'acceptance_rate': acceptance_rate,
            'dead_count': len(dead),
            'avg_permanent_age_days': avg_perm_age,
            'avg_maturation_days': avg_latency,
            'obs_per_instinct': obs_per_instinct,
        },
        'top_instincts': [
            {'name': i['id'], 'count': i.get('occurrences', 0), 'domain': i.get('domain', '?'), 'level': i['level']}
            for i in top_instincts
        ],
        'dead_instincts': dead[:10],
        'top_rules': top_rules,
        'proposal_types': ptypes,
        'velocity_weeks': velocity_weeks,
        'hour_distribution': hour_dist,
        'heatmap_21': heatmap_q,
        'heatmap_raw': heatmap_21,
        'domain_distribution': dict(domain_cnt),
        'origin_distribution': dict(origin_cnt),
        'projects_top': [{'name': n[:22], 'obs': o} for n, o in top_projects],
        'decisions': [
            {'id': d.get('id'), 'date': d.get('date'), 'title': (d.get('decision') or '')[:70]}
            for d in decisions[:20]
        ],
    }


# ═══════════════════════════════════════════════════════════════════════════
# RENDER
# ═══════════════════════════════════════════════════════════════════════════

def render(data: dict) -> str:
    tpl = TEMPLATE.read_text(encoding='utf-8')
    # Inject JSON as a <script type="application/json">
    payload = json.dumps(data, ensure_ascii=False, default=str)
    tpl = tpl.replace('/*__SINAPSIS_DATA__*/null', payload)
    tpl = tpl.replace('__GENERATED_AT__', data['meta']['date_display'])
    return tpl


def main():
    try:
        instincts = collect_instincts()
        hour_dist, day_act, total_acts = collect_instinct_log()
        passive_counts = collect_passive_log()
        pstats, ptypes = collect_proposals()
        prules = collect_passive_rules()
        skills_total, skills_g, skills_c, skills_s = collect_skills()
        projects_active, obs_total, top_proj = collect_projects()
        decisions = collect_decisions()

        data = compute_metrics(
            instincts, pstats, ptypes, prules, passive_counts,
            hour_dist, day_act, total_acts,
            skills_total, skills_g, skills_c, skills_s,
            projects_active, obs_total, top_proj, decisions
        )

        if not TEMPLATE.exists():
            print(f'ERROR: template not found at {TEMPLATE}', file=sys.stderr)
            sys.exit(1)

        html = render(data)
        OUT.write_text(html, encoding='utf-8')

        # Summary (ASCII-safe for Windows cp1252)
        m = data['meta']
        print(f"[OK] Dashboard written: {OUT}")
        print(f"     Instincts:   {m['total_instincts']}  (P:{m['permanent']} C:{m['confirmed']} D:{m['draft']})")
        print(f"     Passive:     {m['rules_total']}  ({m['rules_loud']} loud / {m['rules_silent']} silent)")
        print(f"     Skills:      {m['skills_total']}  ({m['skills_globals']} global / {m['skills_complete']} complete / {m['skills_stubs']} stubs)")
        print(f"     Projects:    {m['projects_active']}  ({m['observations_total']} observations)")
        print(f"     Activations: {m['total_activations']}")
        print(f"     Proposals:   {m['proposals_pending']} pending, {m['proposals_accepted']} accepted, {m['proposals_discarded']} discarded")
        print(f"     Dead:        {m['dead_count']}")
        print(f"     URL:         http://localhost:8080/_dashboard.html (if preview server is up)")
        print(f"     File:        file:///{str(OUT).replace(chr(92), '/')}")
    except Exception as e:
        print(f'ERROR: {e}', file=sys.stderr)
        raise


if __name__ == '__main__':
    main()
