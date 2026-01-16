# Contributing to GitBar

Thank you for your interest in contributing to GitBar! While this project is not actively seeking code contributions at this time, we welcome bug reports, feature requests, and documentation improvements.

## Table of Contents

- [Code of Conduct](#code-of-conduct)
- [How Can I Contribute?](#how-can-i-contribute)
  - [Reporting Bugs](#reporting-bugs)
  - [Suggesting Features](#suggesting-features)
  - [Pull Requests](#pull-requests)
- [Development Setup](#development-setup)
- [Code Style Guidelines](#code-style-guidelines)
- [Commit Message Guidelines](#commit-message-guidelines)

## Code of Conduct

This project and everyone participating in it is governed by our [Code of Conduct](CODE_OF_CONDUCT.md). By participating, you are expected to uphold this code.

## How Can I Contribute?

### Reporting Bugs

Bug reports help us improve GitBar. When filing a bug report, please use the bug report template and include:

- **Clear title and description**: Summarize the issue in the title and provide detailed steps to reproduce in the description
- **System information**: macOS version, GitBar version, Git version
- **Steps to reproduce**: Detailed steps that reliably reproduce the issue
- **Expected behavior**: What you expected to happen
- **Actual behavior**: What actually happened
- **Screenshots/logs**: If applicable, include screenshots or relevant logs
- **Additional context**: Any other information that might be relevant

### Suggesting Features

Feature requests are welcome! Please use the feature request template and include:

- **Clear description**: What feature you'd like to see and why
- **Use case**: Describe the problem this feature would solve
- **Alternatives considered**: Other solutions you've thought about
- **Additional context**: Screenshots, mockups, or examples from other apps

### Pull Requests

If you'd like to contribute code:

1. **Fork the repository** and create your branch from `main`
2. **Follow the development setup** instructions in [BUILD.md](BUILD.md)
3. **Follow our code style guidelines** (see below)
4. **Write descriptive commit messages** (see guidelines below)
5. **Test your changes** thoroughly
6. **Update documentation** if you're changing functionality
7. **Submit a pull request** with a clear description of the changes

**Note:** By submitting a pull request, you agree to license your contribution under the MIT License.

## Development Setup

See [BUILD.md](BUILD.md) for comprehensive setup instructions. Quick start:

```bash
# Clone your fork
git clone https://github.com/yourusername/gitbar.git
cd gitbar

# Open in Xcode
open GitBar.xcodeproj

# Build
xcodebuild -project GitBar.xcodeproj -scheme GitBar -configuration Debug
```

## Code Style Guidelines

### Swift Style

- Follow [Swift API Design Guidelines](https://swift.org/documentation/api-design-guidelines/)
- Use **4 spaces** for indentation (not tabs)
- Maximum line length: **120 characters**
- Use meaningful variable and function names
- Prefer `let` over `var` when possible
- Use Swift's type inference when the type is obvious

### Formatting

```swift
// Good
func fetchRepositoryStatus(for project: Project) async throws -> GitStatus {
    let status = try await git.status(in: project.path)
    return status
}

// Bad
func fetchRepositoryStatus(for project:Project) async throws->GitStatus{
let status=try await git.status(in:project.path)
return status
}
```

### SwiftUI Conventions

- Keep views focused and composable
- Extract complex views into separate structs
- Use view modifiers in consistent order:
  1. Frame and layout modifiers
  2. Styling modifiers (background, foreground, etc.)
  3. Interaction modifiers (onTapGesture, etc.)

### Comments

- Write self-documenting code when possible
- Use comments to explain **why**, not **what**
- Document public APIs with Swift documentation comments:

```swift
/// Fetches the current git status for a repository.
///
/// - Parameter path: The file system path to the git repository
/// - Returns: A `GitStatus` object containing branch info and changes
/// - Throws: `GitError` if the path is not a valid git repository
func status(at path: String) async throws -> GitStatus {
    // Implementation
}
```

### Architecture

- Follow the existing MVVM pattern
- Keep business logic separate from views
- Use async/await for asynchronous operations
- Prefer protocols for testability and abstraction

## Commit Message Guidelines

Write clear, descriptive commit messages that explain the **why** behind changes:

### Format

```
<type>: <subject>

[optional body]

[optional footer]
```

### Types

- **feat**: New feature
- **fix**: Bug fix
- **docs**: Documentation changes
- **style**: Code style changes (formatting, no logic changes)
- **refactor**: Code refactoring
- **test**: Adding or updating tests
- **chore**: Maintenance tasks, build changes, etc.

### Examples

```
feat: Add support for custom git repository locations

Allows users to manually add any git repository folder to the
monitored projects list. Persists selections using app-scoped
security bookmarks.

Closes #42
```

```
fix: Resolve crash when git remote is not configured

The app crashed when trying to fetch remote status for repositories
without a configured remote. Now gracefully handles this case by
showing "No remote" in the UI.

Fixes #56
```

### Best Practices

- Use present tense ("Add feature" not "Added feature")
- Use imperative mood ("Move cursor to..." not "Moves cursor to...")
- First line should be 72 characters or less
- Reference issues and pull requests when relevant
- Explain **why** you made the change in the body

## Testing

Before submitting a pull request:

1. **Build the project**: Ensure it builds without warnings
2. **Test manually**: Exercise your changes in the app
3. **Test edge cases**: Try unusual inputs, empty states, error conditions
4. **Test on a clean system**: If possible, test on a Mac without developer tools

```bash
# Build and verify
xcodebuild -project GitBar.xcodeproj -scheme GitBar -configuration Debug
```

## Questions?

If you have questions about contributing, please:

1. Check existing [issues](https://github.com/yourusername/gitbar/issues)
2. Review the [documentation](BUILD.md)
3. Open a new issue with the "question" label

Thank you for contributing to GitBar!
