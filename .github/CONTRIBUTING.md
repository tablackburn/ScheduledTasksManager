# Contributing

Contributions are welcome! Please follow these guidelines:

## Issues

- Check existing issues before creating a new one
- Provide clear reproduction steps for bugs
- Explain the use case for feature requests

## Pull Requests

1. Fork the repository
2. Create a feature branch: `git checkout -b feature-name`
3. Make your changes
4. Add tests for new functionality
5. Run tests: `./build.ps1 -Task Test`
6. Submit a pull request to the `main` branch

## Code Standards

- Follow existing code style
- Include Pester tests for new functions
- Update documentation as needed
- Use approved PowerShell verbs
- Follow [Semantic Versioning](https://semver.org/) for version changes
- Update [CHANGELOG.md](../CHANGELOG.md) following [Keep a Changelog](https://keepachangelog.com/) format

## Development Setup

- Install PowerShell 7+
- Run `./build.ps1 -Task Init -Bootstrap` to install dependencies
- Run `./build.ps1 -Task Build` to build the module
- Run `./build.ps1 -Task Test` to run tests

## Releasing

When releasing a new version:

1. Update `ModuleVersion` in `ScheduledTasksManager/ScheduledTasksManager.psd1`
2. Add entry to [CHANGELOG.md](../CHANGELOG.md) following [Keep a Changelog](https://keepachangelog.com/) format
3. Commit and push to `main`
4. GitHub Actions will auto-create a release, but the notes will be generic
5. Update the GitHub release notes to match the CHANGELOG entry:
   ```bash
   gh release edit vX.Y.Z --notes "$(cat <<'EOF'
   ## Fixed/Added/Changed
   - Description from CHANGELOG
   EOF
   )"
   ```
