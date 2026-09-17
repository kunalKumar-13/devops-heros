# Git Homework Tasks

Both tasks were carried out in throwaway git repositories; the `console` blocks in the
files below are real captured terminal output, commit hashes included.

| Task | File | What it shows |
|---|---|---|
| 1 | [`task1-commit-a-m.md`](task1-commit-a-m.md) | `git commit -a -m` vs `git commit -m`, both tested side by side |
| 2 | [`task2-cherry-pick.md`](task2-cherry-pick.md) | 4 commits on `main`, 3 on a new branch, one of them cherry-picked into `main` and verified |

## Task 1 in one line

`git commit -m` commits **only what is staged**. `git commit -a -m` also stages every
**modified tracked** file first — but it never adds a **new untracked** file, which
still needs `git add`. Proven in the run: `git commit -m` refused with
*"no changes added to commit"*, `git commit -a -m` committed the modified file, and the
new file stayed untracked until it was added explicitly.

## Task 2 in one line

`git cherry-pick <hash>` copies one specific commit onto the current branch as a **new
commit with a new hash**. In the run, `feature commit 2: FIX README typo` (`988b4de` on
`feature`) was cherry-picked onto `main`, where it became `283c949` — the README fix
arrived, and `auth.js` from the other two feature commits did not.
