#!/usr/bin/env python3
"""Cost and latency of one /pr-review run, from its session transcript.

    scripts/review-stats.py                 # newest session under ~/.claude/projects
    scripts/review-stats.py <session.jsonl> # a specific one

Reports per-agent turns and tokens, and the wall clock from the first tool call
to the last. Turn count is the number to watch: an agent's cache read grows with
the square of it, and its latency grows linearly.
"""
import json, sys, glob, os, datetime

def load(path):
    for line in open(path):
        try:
            yield json.loads(line)
        except ValueError:
            continue

def usage(path):
    tot = dict(out=0, cw=0, cr=0)
    turns = 0
    first = last = None
    keys = dict(out='output_tokens', cw='cache_creation_input_tokens', cr='cache_read_input_tokens')
    for d in load(path):
        ts = d.get('timestamp')
        if ts:
            first = first or ts
            last = ts
        u = (d.get('message') or {}).get('usage')
        if u:
            turns += 1
            for k, src in keys.items():
                tot[k] += u.get(src, 0) or 0
    return turns, tot, first, last

def mins(a, b):
    if not (a and b):
        return 0.0
    f = '%Y-%m-%dT%H:%M:%S.%fZ'
    return (datetime.datetime.strptime(b, f) - datetime.datetime.strptime(a, f)).total_seconds() / 60

def main():
    if len(sys.argv) > 1:
        sess = sys.argv[1]
    else:
        cand = glob.glob(os.path.expanduser('~/.claude/projects/*/*.jsonl'))
        sess = max(cand, key=os.path.getmtime)
    root = sess[:-6]
    print(f'session: {sess}')

    turns, tot, first, last = usage(sess)
    rows = [('main session', turns, tot, mins(first, last))]

    for f in sorted(glob.glob(root + '/subagents/*.jsonl')):
        meta = json.load(open(f.replace('.jsonl', '.meta.json')))
        t, u, a, b = usage(f)
        rows.append((meta['agentType'].split(':')[-1], t, u, mins(a, b)))

    print(f'{"agent":<22}{"turns":>6}{"out":>9}{"cache wr":>10}{"cache rd":>11}{"mins":>7}')
    agg = dict(out=0, cw=0, cr=0)
    for name, t, u, m in rows:
        print(f'{name:<22}{t:>6}{u["out"]:>9}{u["cw"]:>10}{u["cr"]:>11}{m:>7.1f}')
        if name != 'main session':
            for k in agg:
                agg[k] += u[k]
    print(f'{"agents total":<22}{"":>6}{agg["out"]:>9}{agg["cw"]:>10}{agg["cr"]:>11}')
    print(f'\nwall clock (whole session): {mins(first, last):.1f} min')
    print('critical path is the slowest single agent, not the sum.')

main()
