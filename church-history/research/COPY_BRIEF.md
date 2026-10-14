# Copy pass brief

You are copy-editing one research file for an interactive church-history map aimed at a Protestant layperson who is learning about the sacraments. Edit the file IN PLACE. Touch only these text fields: name, summary, why, facts, sacraments, today, disputed. Do not change ids, types, years, parents, on, splits, importance, outsideNicene, or sources. Keep valid JSON (validate with python3 -c "import json;json.load(open(PATH))").

Apply every rule in /Users/zackbart/.agents/skills/unslop/SKILL.md (read it first). The most common problems in these files:

- `why` must say why the thing matters to a reader in plain words, as a direct claim. Never start with a meta verb like "Explains", "Shows", "Distinguishes", "Provides", "Marks", "Highlights", "Illustrates". Bad: "Explains why churches defended the Old Testament." Good: "It is why churches kept the Old Testament as Scripture."
- No em dashes, en dashes, or parentheses used as dashes. No semicolons where a period works. Straight quotes only.
- Short sentences, active voice, name who did what. Cut filler and hedges.
- `name`: max 4 words, the name a layperson would recognize (e.g. "Church of the East", not "Church of East").
- `summary` max 30 words, `why` max 25, each fact max 18, `sacraments` max 30, `today` max 12, `disputed` max 25.
- Keep sacraments text precise: count, baptism view, communion view. Do not blur doctrine to make it shorter.
- Stay neutral between traditions.

If while editing you notice a factual error, fix it and add a source URL to that node's sources. Do not add or remove nodes.

Final reply: one line saying how many nodes you edited and any factual fixes you made.
