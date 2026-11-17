# Contributing to DeployKit Guardian

Thanks for your interest in contributing! This project welcomes real fixes,
real tests, and real documentation improvements.

## How to contribute

1. **Open an issue first** for anything that changes scope (new module, new
   profile semantics, behavior changes). Small bug fixes can go straight to a PR.
2. **Fork & branch**: work on a feature branch from `main`.
3. **Sign off commits** (`git commit -s`) — see [DCO](DCO.md).
4. **Test before you submit**:
   - `bash -n` over any changed shell scripts;
   - `bash tests/test_guardian_e2e.sh` must pass (full sandbox flow);
   - new features need a test that can fail.

## Ground rules

- **Outbound-only, read-only**: guardian components must never open inbound
  ports or modify the guarded system. PRs violating this are rejected.
- **Fingerprints, not contents**: reports and webhooks carry fingerprints and
  levels only — never user data.
- **Clean uninstall**: every installable component must be removable with one
  command, no residue. New files must live under `GUARDIAN_HOME` or the repo.
- **Honest changelog**: every user-visible change gets a CHANGELOG entry.
- No proprietary keys, tokens, or customer environment details in the repo — ever.

## Reporting security issues

See [SECURITY.md](SECURITY.md). Please do not open public issues for
vulnerabilities.

## License

By contributing, you agree that your contributions will be licensed under the
MIT License (see [LICENSE](LICENSE)).
