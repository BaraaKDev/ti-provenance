# Subjects

**Real work goes here. [`samples/`](../samples/) holds the shipped reference set and should be left
alone.**

The two folders have identical structure on purpose — the same scripts, validators and skills run
against either, and nothing in the pipeline cares which one it is pointed at. The split is about
what a folder *means*:

| | |
|---|---|
| [`samples/`](../samples/) | Six worked examples that ship with the project. They are documentation: the schema docs and the report guides point at them, and the test harness reads them for its positive cases. Changing one changes the reference. |
| `subjects/` | Actual bulletins you produce. Nothing here is referenced by any guide or test, so you can add, rewrite and delete freely. |

## Layout

One folder per subject, named by slug — lowercase, hyphenated, folder-safe, and **settled before
the first step runs**, because every artefact is written into it and renaming later orphans them
all.

```
subjects/<slug>/
  handoff/                        machine handoff, JSON, one writer each
    analysis.json                   framing, risk, sources
    mapping.json                    tactics and techniques
  reports/                        the two halves a human reviews
    analysis.html                   the prose report
    <name>-flow.html                the ATT&CK attack flow
  bulletin/
    <slug>-threat-bulletin.html     the two halves merged
```

The finished PDF does **not** land here. It goes to [`output/`](../output/) at the project root, so
that "what have we published" is one directory listing rather than a walk through every subject.

## Slugs

| Subject | Slug | Example |
|---|---|---|
| Actor | the primary tracked name | `andariel` |
| Vulnerability with a common name | that name | `log4j` |
| Vulnerability without one | the CVE, lowercased | `cve-2026-68820` |
| A patch set or advisory batch | vendor plus period | `windows-2026-08` |
| Campaign | the actor's slug | `agrius` |

## Producing one

Run `/threat-report` with an actor name, a vulnerability, or a link to reporting about one. It
picks the slug, creates the folder here, and drives every step through to the PDF.



subject can sit alongside this file.
