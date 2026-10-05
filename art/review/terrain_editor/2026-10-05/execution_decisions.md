# Native execution decisions

The approved implementation ran task by task in this chat. One independent final reviewer inspected the whole branch; both important findings were fixed using failing regressions followed by a clean full suite. No review minor was deferred.

Decisions, in the order recorded:

1. Use an isolated native checkout without repeating approval. It protected unrelated primary-project changes while implementing the approved replacement. Cost if wrong: additional transfer work at delivery. The resulting branch is now delivered locally.
2. Repair the legacy running-turn test fixture’s missing build_mode property. The real player contract already requires it; the full suite exposed a script error despite a zero exit code. Cost if wrong: a fixture-only adjustment; character production behavior was not changed.
3. Perform final review during the running stability wait. Implementation and short benchmarks were already complete; review belongs before integration. Cost if wrong: any product fixes require fresh tests and relevant benchmark/stability reruns. Two findings required exactly that; superseded measurements were replaced.
4. Deliver the active-demo replacement locally under the already-approved plan. The requested outcome explicitly changes the project entry, and current developer guidance prioritizes existing/implied authorization over repeated permission gates. Cost if wrong: the local fast-forward is reversible; there was no remote push/publication. All unrelated local file hashes were preserved.

Deferred minors: none. Final subjective art acceptance, Windows thin-laptop/MacBook Air measurements and long-idle power acceptance remain separate future measurements, as specified before implementation.
