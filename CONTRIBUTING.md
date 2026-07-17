# Contributing to Vibemis Qt

## Git Workflow

We use a **Git Flow** branching strategy to ensure organized development and stable releases.

### Branch Structure

- **`main`** - Stable releases only. All code here should be production-ready.
- **`develop`** - Active development branch. All features merge here first.
- **`feature/*`** - Individual feature branches (e.g., `feature/clipboard-sync`)
- **`hotfix/*`** - Critical fixes that need to go directly to main

### Development Process

#### 1. Starting a New Feature

```bash
# Make sure you're on develop and it's up to date
git checkout develop
git pull origin develop

# Create a new feature branch
git checkout -b feature/your-feature-name

# Push the branch to GitHub
git push -u origin feature/your-feature-name
```

#### 2. Working on Your Feature

```bash
# Make your changes and commit regularly
git add .
git commit -m "Add clipboard sync protocol messages"

# Push changes to your feature branch
git push origin feature/your-feature-name
```

#### 3. Submitting Your Work

1. **Create a Pull Request** from `feature/your-feature-name` → `develop`
2. **Fill out the PR template** with:
   - Description of changes
   - Testing performed
   - Screenshots/videos if UI changes
   - Related issues

3. **Wait for review** and address any feedback
4. **Merge to develop** once approved

#### 4. Releasing to Main

1. **Create a Pull Request** from `develop` → `main` 
2. **Full testing** on all platforms
3. **Version bump** and changelog update
4. **Merge and tag** for release

### Example Feature Development

Let's implement clipboard sync as an example:

```bash
# Start the feature
git checkout develop
git pull origin develop
git checkout -b feature/clipboard-sync
git push -u origin feature/clipboard-sync

# Work on the feature...
# (implement clipboard sync functionality)

# Commit your work
git add .
git commit -m "Implement clipboard sync with Apollo protocol"
git push origin feature/clipboard-sync

# Create PR: feature/clipboard-sync → develop
# After review and approval, merge to develop

# Later, when ready for release:
# Create PR: develop → main
# Tag release after merge
```

## CI/CD Integration

### Automated Testing
- **Test workflow** runs on pushes to `develop` and all PRs
- **Build workflow** runs on pushes to `main` and release creation
- All platforms (Windows, macOS, Linux, Steam Deck) are tested

### Build Artifacts
- **Steam Deck**: Optimized build with embedded config
- **Windows**: x64 and ARM64 portable packages
- **macOS**: Universal DMG
- **Linux**: AppImage for broad compatibility
- **Steam Link**: Dedicated build

## Code Standards

### Commit Messages
Use conventional commits format:
```
type(scope): brief description

feat(clipboard): add clipboard sync functionality
fix(ui): resolve settings dialog crash
docs(readme): update installation instructions
```

### Code Style
- Follow existing Qt/C++ conventions in the codebase
- Use meaningful variable and function names
- Comment complex logic
- Keep functions focused and reasonably sized

### Testing
- Test your changes on at least one platform locally
- Include unit tests for new functionality when applicable
- Verify UI changes work across different screen sizes
- Test with both Apollo and Sunshine servers when relevant

## Feature Implementation Guidelines

### Research Phase
1. **Study Android implementation** - Check `vibemis-android` for reference
2. **Understand protocol** - Review how Apollo/Sunshine handle the feature
3. **Plan Qt integration** - Consider Qt-specific APIs and patterns

### Implementation Phase
1. **Start with backend** - Implement protocol/networking changes
2. **Add UI controls** - Create settings and user interfaces
3. **Test thoroughly** - Verify functionality across platforms
4. **Document changes** - Update relevant documentation

### Review Phase
1. **Self-review** - Check your own code before submitting
2. **Test build** - Ensure CI passes on all platforms
3. **Update docs** - Include user-facing documentation
4. **Respond to feedback** - Address review comments promptly

## Vibemis commit format and PR scorecard

These conventions apply to all `vibemis-main` work (the repo's actual integration branch — see
`docs/DEVELOPMENT.md`) and to every contributor.

### Commit message format

```
<type>(<optional scope>): <short description>

<body — what AND why>
<references: test reports, related PRs, issue numbers>
```

Types: `feat`, `fix`, `docs`, `chore`, `testing`, `refactor`

Examples:
- `fix: surgical libva symlink to avoid Qt version collision`
- `docs: rewrite README as Vibemis-native document`

### PR body — four-test scorecard

Every feature/fix PR targeting `vibemis-main` must include this section:

```markdown
## Summary
- <bullet 1 — what changed>
- <bullet 2 — why>

## Test scorecard
- [ ] Build: clean build on this branch (qmake6 + make, exit 0)
- [ ] Smoke: <what was tested and the result>
- [ ] Regression: <prior features verified still working>
- [ ] Negative: <what happens when the precondition is missing>
```

Build and negative tests can often be done without special hardware. Smoke and regression tests
that need a real display/GPU require hardware verification — see `docs/SELFTEST.md` for the
scriptable checks that can substitute for a chunk of that (headless `selftest`, log-driven
assertions, CLI host checks).

## Getting Help

- **Discord**: Join the community discussions
- **Issues**: Create GitHub issues for bugs or feature requests
- **Discussions**: Use GitHub Discussions for questions
- **Code Review**: Ask for help during PR reviews

---

Thank you for contributing to Vibemis Qt! 🚀
