## replix — Plan 9 replica tools for Unix in AWK

**replix** is a small AWK‑ and Shell‑based re‑implementation of a
few Plan 9 replica(8)[^1] commands. It’s meant for simple synchronization
and change‑tracking tasks on Unix‑like systems.

The code is intentionally minimal. It runs best on **macOS** and
the **BSDs**; **Linux** users may need to adjust a few commands or
AWK behaviors. The included **test suite** shows the expected
behavior and helps anyone adapting the code to other systems.

See **example.mk** and **example.proto** for basic usage patterns.

---
[^1]: *[replica](http://9p.io/magic/man2html/8/replica)*(8)
