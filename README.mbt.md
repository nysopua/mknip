# mknip

Dead code detector for MoonBit. Inspired by [knip](https://github.com/webpro/knip).

## Features

- **Unused exports** - Find `pub` symbols not referenced from entry points
- **Unreachable files** - Detect `.mbt` files with no path from `main`/`init`
- **Unused dependencies** - Find packages in `moon.pkg.json` / `moon.pkg` not actually used
- **Implicit deps** - Recognizes `async` keyword requires `moonbitlang/async`

## Usage

```bash
moon run cmd/main -- /path/to/project
```

### Example Output

```
mknip v0.1.0
Analyzing ../my-project...

Unreachable Files (1)
─────────────────────────────────
  ✗ src/unused_module.mbt

Unused Types (2)
─────────────────────────────────
  ◇ OldConfig (struct) src/types.mbt:42
  ◆ DeprecatedError (enum) src/errors.mbt:10

Unused Functions (3)
─────────────────────────────────
  λ legacy_handler (fn) src/handlers.mbt:55
  ▫ debug_mode (let) src/config.mbt:8

Unused Dependencies (1)
─────────────────────────────────
  ✗ moonbitlang/some-unused-package

⚠ Found 7 issue(s)
```

## How It Works

1. Scans for `moon.pkg.json` or `moon.pkg` files
2. Identifies **main packages** (`is-main: true`) as entry points
3. Finds `fn main` / `fn init` as reachability roots
4. BFS traversal to mark reachable symbols
5. Reports unreachable `pub` exports

Library packages (`is-main: false`) are excluded from unused detection—all their `pub` exports are considered API.

## Supported Formats

| Format | File | Example |
|--------|------|---------|
| JSON | `moon.pkg.json` | `{"is-main": true, "import": [...]}` |
| DSL | `moon.pkg` | `import { "pkg/name" }` |

## Limitations

- No cross-package analysis (single package only)
- Trait impl detection is basic
- No dead code inside functions

## TODO

- [ ] Cross-package analysis (workspace support)
- [ ] Better trait impl detection
- [ ] JSON output (`--format json`)
- [ ] Config file (`.mkniprc`)
- [ ] Ignore patterns (`// mknip-ignore`)
- [ ] CI integration examples
- [ ] mooncakes publish
