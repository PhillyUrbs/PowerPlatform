#!/usr/bin/env python3
import json, os, re, sys

def fail(msg):
    print(f"ERROR: {msg}", file=sys.stderr)
    sys.exit(1)

# 1. Parse solutions.json
if not os.path.isfile('solutions.json'):
    fail('solutions.json not found')
try:
    with open('solutions.json','r',encoding='utf-8') as f:
        solutions=json.load(f)
except Exception as e:
    fail(f'failed to parse solutions.json: {e}')
if not isinstance(solutions, list) or not all(isinstance(x,str) for x in solutions):
    fail('solutions.json must be an array of strings')
solutions=[s.strip() for s in solutions if s.strip()]
print(f"solutions.json entries: {solutions}")

# 2. Collect directories under solutions/
sol_dirs=[]
if os.path.isdir('solutions'):
    for entry in os.listdir('solutions'):
        p=os.path.join('solutions', entry)
        if os.path.isdir(p) and not entry.startswith('.'):
            sol_dirs.append(entry)
sol_dirs.sort()
print(f"solution directories: {sol_dirs}")
missing=[s for s in solutions if s not in sol_dirs]
extra=[d for d in sol_dirs if d not in solutions]
if missing:
    fail(f'solutions listed in solutions.json but missing directories: {missing}')
if extra:
    fail(f'directories present under solutions/ but missing from solutions.json: {extra}')

# 3. Validate workflow dropdown blocks
marker_start=re.compile(r'#\s*GENERATED-OPTIONS-START')
marker_end=re.compile(r'#\s*GENERATED-OPTIONS-END')
workflow_paths=[
    '.github/workflows/export-solution-from-dev.yml',
    '.github/workflows/release-action-call.yml',
    '.github/workflows/release-solution-manual.yml',
    '.github/workflows/delete-solution.yml'
]
expected=set(solutions)
errors=[]
for wf in workflow_paths:
    if not os.path.isfile(wf):
        errors.append(f'missing workflow expected for sync: {wf}')
        continue
    with open(wf,'r',encoding='utf-8') as f:
        lines=f.read().splitlines()
    try:
        si=next(i for i,l in enumerate(lines) if marker_start.search(l))
        ei=next(i for i,l in enumerate(lines) if marker_end.search(l))
    except StopIteration:
        errors.append(f'markers missing in {wf}')
        continue
    if ei <= si:
        errors.append(f'markers malformed in {wf}')
        continue
    block=lines[si+1:ei]
    opts=[ln.strip().split('- ',1)[1].strip() for ln in block if ln.strip().startswith('- ')]
    got=set(o for o in opts if o != '<none>')
    if got != expected:
        errors.append(f'{wf} options mismatch got={sorted(got)} expected={sorted(expected)}')

if errors:
    for e in errors:
        print('ERROR: '+e, file=sys.stderr)
    sys.exit(1)

print('All solution configuration checks passed.')
