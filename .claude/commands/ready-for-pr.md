---
description: Get this branch ready for a pull request into production (rebase, checks, rule review)
---

Prepare the current branch for a pull request into `production`. Do every
step; stop and report if one fails and cannot be fixed safely.

1. Confirm the branch is the teammate's own branch (see the table in
   CLAUDE.md), never `production`. Commit any finished work.
2. `git fetch origin && git rebase origin/production`. Resolve conflicts by
   keeping production's behaviour and re-applying this branch's change on
   top. If code here uses something production removed, switch to what
   replaced it (`git log -S <name> origin/production`); never re-add it.
3. Run `flutter analyze` — no errors or warnings in changed files.
4. Run `flutter test` — everything passes, including
   `test/architecture_guard_test.dart`. Never weaken that test.
5. Review `git diff origin/production...HEAD` against every rule under
   "Architecture rules" in CLAUDE.md. List each rule with pass / fail and
   fix every fail. Also check: no secrets, no unrelated reformatting, no
   leftover debug code, formal English in the UI, tests for new logic.
6. If the change revives a removed feature or changes product behaviour the
   owner decided, stop and say so — it needs the owner's OK first.
7. Push the branch (`git push origin <branch>`, never force over others'
   commits) and open the PR:
   `gh pr create --base production --head <branch>` with a body that says
   what changed, why, how it was tested, and the rule review from step 5.
