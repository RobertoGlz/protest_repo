"""Count words in the main body of the paper (Intro through end of Discussion),
excluding tables, figures, captions/notes, footnotes, references, and section
headers."""
import re

with open("violent-effects-of-apex-corruption-main.tex", "r", encoding="utf-8") as f:
    tex = f.read()

# Trim to body: Introduction section through REFERENCES banner
start = tex.find("\\section{Introduction}")
end   = tex.find("REFERENCES")
body  = tex[start:end] if (start >= 0 and end > start) else tex

# Strip \begin{env}...\end{env} for common environments via string ops
def strip_env(s, env):
    st, et = "\\begin{" + env + "}", "\\end{" + env + "}"
    out, i = [], 0
    while True:
        j = s.find(st, i)
        if j < 0:
            out.append(s[i:])
            break
        out.append(s[i:j])
        k = s.find(et, j)
        if k < 0:
            break
        i = k + len(et)
    return "".join(out)

for env in ("table", "figure", "equation", "align", "align*",
            "subequations", "tabular", "subfigure", "center", "minipage"):
    body = strip_env(body, env)

# Strip \footnote{...} with balanced-brace walk
def strip_footnotes(s):
    key = "\\footnote{"
    out, i = [], 0
    while i < len(s):
        if s[i:i + len(key)] == key:
            d, i = 1, i + len(key)
            while i < len(s) and d > 0:
                if s[i] == "{":
                    d += 1
                elif s[i] == "}":
                    d -= 1
                i += 1
        else:
            out.append(s[i])
            i += 1
    return "".join(out)

body = strip_footnotes(body)

# Strip common LaTeX commands using patterns without \{ (which Python 3.12
# treats as a bad escape). Since { and } are only regex metachars in a
# quantifier position, we can leave them unescaped.
patterns_to_kill = [
    r"\\section\*?[ \t]*{[^}]*}",
    r"\\subsection\*?[ \t]*{[^}]*}",
    r"\\label[ \t]*{[^}]*}",
]
for p in patterns_to_kill:
    body = re.sub(p, " ", body)

patterns_to_placeholder = [
    (r"\\autoref[ \t]*{[^}]*}", "REF"),
    (r"\\ref[ \t]*{[^}]*}", "REF"),
    (r"\\eqref[ \t]*{[^}]*}", "REF"),
    (r"\\citep\*?[ \t]*{[^}]*}", "CITE"),
    (r"\\citet\*?[ \t]*{[^}]*}", "CITE"),
    (r"\\cite\*?[ \t]*{[^}]*}", "CITE"),
    (r"\\href[ \t]*{[^}]*}[ \t]*{[^}]*}", "HREF"),
]
for p, repl in patterns_to_placeholder:
    body = re.sub(p, repl, body)

# Keep content of a few "content-preserving" wrappers
for cmd in ("hl", "emph", "textit", "textbf", "text"):
    body = re.sub(r"\\" + cmd + r"[ \t]*{([^}]*)}", r"\1", body)

# Strip inline math
body = re.sub(r"\$[^$]*\$", "MATH", body)
# Strip remaining generic \foo{...} and \foo
body = re.sub(r"\\[A-Za-z]+\*?[ \t]*{[^}]*}", " ", body)
body = re.sub(r"\\[A-Za-z]+\*?", " ", body)
# LaTeX line comments
body = re.sub(r"%.*", " ", body)
# Stray braces
body = re.sub(r"[{}]", " ", body)
body = body.replace("---", " ").replace("--", " ")

words = body.split()
print("Main-text word count (Introduction + Method prose + Results prose + Discussion)")
print("  excluding: title/authors/abstract, table+figure environments, captions/notes,")
print("  footnotes, references, section headers, math, and LaTeX cruft:")
print(f"  => {len(words)} words")
