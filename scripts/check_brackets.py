import sys
from pathlib import Path
p = Path(r"e:/Data/Programming/Code/Flutter/beadline/lib/views/playlists_management_page.dart")
s = p.read_text(encoding='utf-8')
stack = []
pairs = {'}':'{', ')':'(', ']':'['}
for i,ch in enumerate(s, start=1):
    if ch in '{([':
        stack.append((ch,i))
    elif ch in '})]':
        if not stack:
            print(f"Unmatched closing {ch} at pos {i}")
            sys.exit(0)
        top, pos = stack.pop()
        if pairs[ch] != top:
            print(f"Mismatched {top} at {pos} with {ch} at {i}")
            sys.exit(0)
if stack:
    for ch,pos in stack:
        print(f"Unmatched opening {ch} at pos {pos}")
else:
    print("All braces match")
