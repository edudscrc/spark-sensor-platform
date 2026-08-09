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
