# Phase 0.5 — Professional Git and GitHub Workflow

This phase adds a professional Git/GitHub development workflow to the Spark + Kafka + Docker + PostgreSQL learning project.

The objective is not only to learn Git commands, but to practice the same development lifecycle commonly used by engineering teams:

```text
Issue / Task
    ↓
Create branch
    ↓
Develop
    ↓
Make focused commits
    ↓
Push branch
    ↓
Open Pull Request
    ↓
Self-review / team review
    ↓
Resolve comments
    ↓
Merge
    ↓
Delete branch
    ↓
Update local main
```

The repository is public, so GitHub Rulesets are available.

---

## 0.5.1 Learning objectives

By the end of this phase, you should understand:

- the difference between local and remote branches;
- what `origin` means;
- why development should normally happen outside `main`;
- how feature branches are created and deleted;
- how to write useful commit messages;
- what a Pull Request represents;
- how to inspect a PR diff before merging;
- how GitHub repository rules protect `main`;
- how squash merging changes Git history;
- how a Pull Request template standardizes reviews;
- how to synchronize local `main` after a merge;
- the difference between `git merge`, GitHub PR merging, squash merging, and rebasing;
- how this workflow scales from a solo project to a team.

---

## 0.5.2 Verify the repository state

Start from the repository root.

```bash
git status
```

You want the working tree to be clean before introducing the workflow.

Check the current branch:

```bash
git branch --show-current
```

Expected:

```text
main
```

Check the configured remotes:

```bash
git remote -v
```

Normally you should see something similar to:

```text
origin  git@github.com:<user>/<repository>.git (fetch)
origin  git@github.com:<user>/<repository>.git (push)
```

or an HTTPS URL.

`origin` is simply the conventional name Git gives to the primary remote repository.

Check that local `main` is synchronized:

```bash
git pull --ff-only
```

The `--ff-only` option tells Git not to create an unexpected merge commit while updating `main`.

---

## 0.5.3 Configure repository merge behavior

Open the repository on GitHub.

Go to:

```text
Repository
→ Settings
→ General
→ Pull Requests
```

For this learning project, use the following configuration.

Enable:

- **Allow squash merging**
- **Automatically delete head branches**

Disable for now:

- **Allow merge commits**
- **Allow rebase merging**

This deliberately gives the project one simple merge strategy:

```text
feature branch commits
        ↓
Pull Request
        ↓
Squash and merge
        ↓
one commit on main
```

Example feature branch:

```text
A---B---C---D  feat/kafka-infrastructure
```

After squash merge:

```text
main

M---S
```

where `S` represents the entire PR as one logical commit.

This keeps `main` easy to inspect while still allowing several intermediate commits while developing a feature.

Later in the project, intentionally enable and experiment with merge commits and rebasing so that you learn the differences.

---

## 0.5.4 Create a ruleset protecting `main`

Go to:

```text
Repository
→ Settings
→ Rules
→ Rulesets
```

Choose:

```text
New ruleset
→ New branch ruleset
```

Use:

```text
Ruleset name:
Protect main

Enforcement status:
Active
```

### Target branch

Under target branches, add the repository's default branch.

The target should effectively be:

```text
main
```

Using the default-branch target is useful because the rule follows the repository's default branch if it is renamed later.

---

## 0.5.5 Recommended rules for this solo project

Enable the following rules.

### Restrict deletions

Enable:

```text
Restrict deletions
```

Purpose: prevent accidental deletion of `main`.

### Require linear history

Enable:

```text
Require linear history
```

Because this project currently uses squash merging, `main` does not need merge commits.

The history stays approximately:

```text
A---B---C---D---E
```

instead of:

```text
A---B-------M
     \     /
      C---D
```

Both styles are valid in professional projects. We use linear history initially because it is easier to inspect while learning.

### Require a pull request before merging

Enable:

```text
Require a pull request before merging
```

This is the most important rule.

It changes the expected workflow from:

```text
local main
    ↓
git push
    ↓
remote main
```

to:

```text
feature branch
    ↓
push
    ↓
Pull Request
    ↓
review
    ↓
main
```

#### Required approvals

Because this is currently a solo repository, configure:

```text
Required approvals: 0
```

Do not require one approval yet.

When working in a team, a common configuration is:

```text
Required approvals: 1
```

or more for sensitive repositories.

#### Require conversation resolution

Enable:

```text
Require conversation resolution before merging
```

This is useful even when working alone.

During self-review you can leave a comment such as:

```text
Should this timeout become an environment variable?
```

The PR should not merge until that conversation has been resolved.

### Block force pushes

Enable:

```text
Block force pushes
```

Force-pushing to `main` can rewrite published history.

This should generally be prohibited on a shared primary branch.

Force pushes can still be useful on feature branches, especially after rebasing, but that is a different situation.

---

## 0.5.6 Rules to leave disabled for now

Do not enable everything merely because GitHub provides it.

### Required status checks

Leave:

```text
Require status checks to pass before merging
```

disabled for now.

Later, when GitHub Actions is introduced, this can require checks such as:

```text
Python tests
Linting
Docker build
Integration tests
```

At that point the lifecycle becomes:

```text
Pull Request
    ↓
GitHub Actions
    ↓
tests pass?
    ├── no  → cannot merge
    └── yes → merge allowed
```

### Require signed commits

Leave signed commits optional initially.

Commit signing is useful and should be learned later, but it is not necessary for understanding the core branch/PR workflow.

### Merge queue

Do not use a merge queue for this solo repository.

Merge queues are much more useful when many developers are concurrently merging changes into a busy branch.

---

## 0.5.7 Recommended ruleset summary

Your `main` ruleset should approximately contain:

```text
Ruleset: Protect main
Status: Active
Target: default branch

[x] Restrict deletions
[x] Require linear history
[x] Require a pull request before merging
    Required approvals: 0
    [x] Require conversation resolution
[x] Block force pushes

[ ] Require status checks              later
[ ] Require signed commits             later
[ ] Require deployments                later
[ ] Merge queue                        not needed now
```

The exact names and grouping of controls can change slightly in GitHub's UI over time.

---

## 0.5.8 Create the first professional workflow branch

Do not make the workflow files directly on `main`.

Make the workflow itself your first PR-managed change.

Start from an updated `main`:

```bash
git switch main
git pull --ff-only
```

Create a branch:

```bash
git switch -c chore/github-workflow
```

Check:

```bash
git branch
```

Expected:

```text
* chore/github-workflow
  main
```

The `*` indicates the currently checked-out branch.

---

## 0.5.9 Add a Pull Request template

Create:

```text
.github/
└── pull_request_template.md
```

Commands:

```bash
mkdir -p .github
touch .github/pull_request_template.md
```

Suggested contents:

````markdown
## Summary

Describe what this pull request changes and why.

## Changes

- 
- 
- 

## How to test

Describe how the change was validated.

```bash
# Commands used to validate the change
```

## Checklist

- [ ] The PR has one clear purpose.
- [ ] I reviewed my own diff.
- [ ] Relevant tests/checks pass.
- [ ] The application still starts correctly.
- [ ] Documentation was updated if required.
- [ ] No secrets, passwords, tokens, or private files were committed.
````

GitHub automatically inserts a PR template into the body of new Pull Requests when the template is stored in a supported location on the default branch.

The `.github` directory is a conventional location for repository-level GitHub configuration.

---

## 0.5.10 Add `CONTRIBUTING.md`

Create:

```bash
touch CONTRIBUTING.md
```

Use an initial policy such as:

````markdown
# Contributing

## Development workflow

Changes should normally be developed on a dedicated branch and merged into
`main` through a Pull Request.

### Branch naming

Use one of the following prefixes:

- `feat/` — new functionality
- `fix/` — bug fixes
- `docs/` — documentation
- `test/` — tests
- `refactor/` — code restructuring without intended behavior changes
- `chore/` — maintenance, tooling, or repository configuration

Examples:

- `feat/kafka-infrastructure`
- `feat/spark-streaming`
- `fix/postgres-healthcheck`
- `docs/docker-networking`
- `chore/github-workflow`

## Commit messages

Prefer the format:

`type(scope): short imperative description`

Examples:

- `feat(postgres): add sensor metrics schema`
- `fix(docker): correct postgres healthcheck`
- `docs(git): document pull request workflow`
- `test(spark): add aggregation tests`

## Pull Requests

Before opening a Pull Request:

1. Update the feature branch as necessary.
2. Review `git status`.
3. Review the complete diff.
4. Run relevant tests.
5. Confirm no secrets were added.

Before merging:

1. Review the GitHub **Files changed** tab.
2. Resolve review conversations.
3. Confirm required checks pass.
4. Use the repository's configured merge method.
````

This file is deliberately simple. It can evolve as the project becomes more sophisticated.

---

## 0.5.11 Inspect changes before committing

Run:

```bash
git status
```

Then:

```bash
git diff
```

For untracked files, `git diff` alone does not show their complete content because they are not yet tracked.

Stage them:

```bash
git add .github/pull_request_template.md CONTRIBUTING.md
```

Now inspect exactly what will enter the next commit:

```bash
git diff --staged
```

This is an important professional habit.

The flow should be:

```text
edit
 ↓
git diff
 ↓
git add
 ↓
git diff --staged
 ↓
commit
```

Do not use `git add .` mechanically without first understanding what files are being staged.

---

## 0.5.12 Create a focused commit

Commit:

```bash
git commit -m "chore(git): establish pull request workflow"
```

Inspect:

```bash
git log --oneline --decorate -5
```

You should see the new commit on:

```text
chore/github-workflow
```

while `main` still points to the older commit.

Conceptually:

```text
main
  |
  A
   \
    B  chore/github-workflow
```

Your change has not entered `main`.

---

## 0.5.13 Push the branch

Run:

```bash
git push -u origin chore/github-workflow
```

The `-u` / `--set-upstream` option associates the local branch with its corresponding remote-tracking branch.

After this, the relationship is approximately:

```text
local branch:
chore/github-workflow

        tracks

remote-tracking branch:
origin/chore/github-workflow
```

For subsequent pushes on this branch, normally:

```bash
git push
```

is enough.

---

## 0.5.14 Open the Pull Request

On GitHub, create a Pull Request with:

```text
base:
main

compare:
chore/github-workflow
```

Suggested title:

```text
chore: establish GitHub development workflow
```

Fill in the PR template.

For this PR, the summary could explain that the change introduces:

- a Pull Request template;
- contribution conventions;
- branch naming conventions;
- commit message conventions;
- self-review expectations.

---

## 0.5.15 Perform a real self-review

Do not immediately merge the PR.

Open:

```text
Pull Request
→ Files changed
```

Review each changed line.

Ask:

```text
Is every file relevant to this PR?

Did I accidentally commit credentials?

Is the wording understandable?

Does the branch contain unrelated changes?

Are the conventions internally consistent?

Could any part be simpler?
```

You can practice GitHub review comments even when working alone.

For example, leave a review comment on one line:

```text
Should we document how hotfix branches will be handled later?
```

If you make a change locally:

```bash
# edit the file

git diff
git add CONTRIBUTING.md
git diff --staged

git commit -m "docs(git): clarify branch conventions"
git push
```

The Pull Request updates automatically because it tracks the branch, not one specific commit.

Resolve the conversation when the concern has been addressed.

---

## 0.5.16 Understand what a Pull Request actually is

A PR is not a separate Git object stored in your local repository.

Git itself primarily knows about:

```text
commits
branches
tags
remotes
```

A Pull Request is a GitHub collaboration construct representing a proposal to integrate one branch into another.

For example:

```text
base branch:
main

head branch:
chore/github-workflow
```

The PR shows the effective difference:

```text
main..chore/github-workflow
```

and adds collaboration metadata:

```text
title
description
comments
reviews
status checks
merge controls
linked issues
```

---

## 0.5.17 Merge the Pull Request

Once the PR is correct and all rules are satisfied, use:

```text
Squash and merge
```

Choose a clean final commit message, for example:

```text
chore(git): establish pull request workflow
```

The individual feature-branch commits are combined into one commit on `main`.

---

## 0.5.18 Automatic remote branch deletion

Because:

```text
Automatically delete head branches
```

was enabled, GitHub should remove the remote feature branch after the PR is merged.

Conceptually:

```text
origin/chore/github-workflow
```

is removed.

Your local branch still exists until you delete it yourself.

---

## 0.5.19 Synchronize your local repository after the merge

After merging on GitHub:

```bash
git switch main
```

Then:

```bash
git pull --ff-only
```

Now local `main` receives the squash commit created by GitHub.

Delete the old local branch:

```bash
git branch -d chore/github-workflow
```

Clean obsolete remote-tracking references:

```bash
git fetch --prune
```

Inspect:

```bash
git branch -a
```

and:

```bash
git log --oneline --graph --decorate --all -10
```

This is the complete lifecycle:

```text
main
 ↓
create feature branch
 ↓
commits
 ↓
push
 ↓
PR
 ↓
review
 ↓
squash merge
 ↓
remote feature branch deleted
 ↓
pull main
 ↓
local feature branch deleted
```

---

## 0.5.20 Standard workflow for every future phase

From now on, use this pattern.

### 1. Synchronize `main`

```bash
git switch main
git pull --ff-only
```

### 2. Create a branch

Example:

```bash
git switch -c feat/kafka-infrastructure
```

### 3. Develop

Edit files.

Frequently inspect:

```bash
git status
git diff
```

### 4. Stage intentionally

```bash
git add <specific-files>
git diff --staged
```

### 5. Commit logically

```bash
git commit -m "feat(kafka): add Kafka Compose service"
```

### 6. Push

First push:

```bash
git push -u origin feat/kafka-infrastructure
```

Later pushes:

```bash
git push
```

### 7. Open a Pull Request

```text
feat/kafka-infrastructure
        ↓
       main
```

### 8. Review

Review the **Files changed** tab and all automated checks.

### 9. Merge

Use:

```text
Squash and merge
```

### 10. Clean up locally

```bash
git switch main
git pull --ff-only
git branch -d feat/kafka-infrastructure
git fetch --prune
```

---

## 0.5.21 Suggested branch naming convention

Use short-lived branches.

```text
feat/<topic>
fix/<topic>
docs/<topic>
test/<topic>
refactor/<topic>
chore/<topic>
```

Examples for this project:

```text
chore/github-workflow
feat/postgres-schema
feat/kafka-infrastructure
feat/kafka-producer
feat/spark-streaming
feat/spark-postgres-sink
fix/postgres-healthcheck
docs/docker-networking
test/spark-aggregation
```

Avoid long-lived branches such as:

```text
development
my-work
updates
new-version
```

unless the project adopts a branching model that specifically requires them.

---

## 0.5.22 Commit message convention

Use approximately:

```text
type(scope): description
```

Recommended types:

```text
feat
fix
docs
test
refactor
chore
build
ci
```

Examples:

```text
feat(kafka): add broker to Compose stack
feat(spark): consume sensor events from Kafka
fix(postgres): correct initialization mount
docs(docker): explain named volumes
test(spark): cover windowed aggregation
ci(github): run Python tests on pull requests
```

A good commit should answer:

```text
What logical change does this commit introduce?
```

Avoid:

```text
update
fix
changes
work
final
final2
stuff
```

---

## 0.5.23 Optional next step: GitHub Issues

After the PR workflow is comfortable, begin representing significant work as Issues.

Example:

```text
Issue #4
Add Kafka development infrastructure
```

Then create:

```text
feat/kafka-infrastructure
```

The eventual PR can contain:

```text
Closes #4
```

When merged, GitHub can automatically close the linked issue.

The complete team-style flow becomes:

```text
Issue
  ↓
Branch
  ↓
Commits
  ↓
Pull Request
  ↓
Review
  ↓
CI
  ↓
Merge
  ↓
Issue closed
```

---

## 0.5.24 Optional later additions

Do not implement all of these immediately.

They will be introduced when there is a concrete reason to learn them.

### GitHub Actions

Later:

```text
.github/workflows/
```

can run:

- Python tests;
- formatting/lint checks;
- Docker builds;
- integration tests.

Then `main` can require those status checks.

### Issue templates

Later add:

```text
.github/
└── ISSUE_TEMPLATE/
    ├── bug.yml
    └── feature.yml
```

### CODEOWNERS

Useful when working with a real team:

```text
.github/CODEOWNERS
```

It can automatically request reviews from people responsible for particular paths.

### Commit signing

Later configure Git/GitHub to create verified signed commits.

### Rebase practice

Later intentionally practice:

```bash
git rebase
git rebase -i
```

and learn why feature-branch force pushes sometimes become necessary.

### Merge conflicts

During a future phase, intentionally create a small merge conflict and resolve it manually.

### Revert

Practice reverting a merged change safely:

```bash
git revert
```

rather than rewriting shared history.

### Cherry-pick

Practice applying one specific commit onto another branch:

```bash
git cherry-pick <commit>
```

---

## 0.5.25 Phase completion checklist

Repository settings:

```text
[ ] `main` is the default branch
[ ] squash merging is enabled
[ ] automatic deletion of merged head branches is enabled
[ ] `main` is targeted by an active GitHub ruleset
[ ] deletion of `main` is restricted
[ ] force pushes to `main` are blocked
[ ] changes to `main` require a Pull Request
[ ] required approvals are set appropriately for a solo repository
[ ] review conversations must be resolved
[ ] linear history is required
```

Repository files:

```text
[ ] `.github/pull_request_template.md` exists
[ ] `CONTRIBUTING.md` exists
```

Workflow:

```text
[ ] `chore/github-workflow` was created from `main`
[ ] changes were committed on the feature branch
[ ] the branch was pushed to GitHub
[ ] a Pull Request was opened
[ ] the PR diff was self-reviewed
[ ] at least one review conversation was practiced
[ ] the conversation was resolved
[ ] the PR was squash-merged
[ ] the remote feature branch was deleted automatically
[ ] local `main` was updated
[ ] the local feature branch was deleted
```

Understanding:

```text
[ ] I understand local branch vs remote-tracking branch
[ ] I understand what `origin` means
[ ] I understand what a Pull Request represents
[ ] I understand why `main` is protected
[ ] I understand why force-pushing `main` is dangerous
[ ] I understand why the project currently uses squash merging
[ ] I understand why required CI checks are postponed
```

---

## Result

After Phase 0.5, development of the remaining project should follow:

```text
Task / Issue
      ↓
new short-lived branch
      ↓
focused commits
      ↓
push
      ↓
Pull Request
      ↓
review + automated checks
      ↓
merge
      ↓
delete branch
      ↓
synchronize local main
```

This workflow should be used for the Kafka, Spark, database, Docker, testing, and CI phases that follow.

---

## References

Official GitHub documentation:

- Rulesets: https://docs.github.com/en/repositories/configuring-branches-and-merges-in-your-repository/managing-rulesets/creating-rulesets-for-a-repository
- Available rules: https://docs.github.com/en/repositories/configuring-branches-and-merges-in-your-repository/managing-rulesets/available-rules-for-rulesets
- Pull request merge methods: https://docs.github.com/en/repositories/configuring-branches-and-merges-in-your-repository/configuring-pull-request-merges/about-merge-methods-on-github
- Automatic branch deletion: https://docs.github.com/en/repositories/configuring-branches-and-merges-in-your-repository/configuring-pull-request-merges/managing-the-automatic-deletion-of-branches
- Pull request templates: https://docs.github.com/en/communities/using-templates-to-encourage-useful-issues-and-pull-requests/about-issue-and-pull-request-templates
