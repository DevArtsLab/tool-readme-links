# tool-readme-links

Keep your README's "Live Demo" link in sync with your repository's **About**
section automatically.

GitHub Markdown has no variable substitution, so a live link must be written
into the file. This tool does that for you: a small script reads the
repository's `homepage` field (the website URL in the About section) via the
GitHub API and rewrites a marked block in your README. If no homepage is set,
the same link markup is written with a placeholder URL, so the rendered README
looks identical either way.

It ships as:

- a **composite GitHub Action** (`action.yml`) you can `uses:` in any repo, and
- a **standalone bash script** (`scripts/update-live-link.sh`) you can run
  locally or from any CI.

## Live Demo

<!-- live-link:start -->

[View the Live Site](https://example.com/your-live-url)

<!-- live-link:end -->

(The block above is maintained by this repository's own
[workflow](.github/workflows/update-readme-live-link.yml) as a live example.)

## Setup in your repository

### 1. Add markers to your README

```markdown
## Live Demo

<!-- live-link:start -->
<!-- live-link:end -->
```

Everything between the markers is managed by the tool. Keep the text, heading,
and layout you want outside the markers.

### 2. Add the workflow

Copy [examples/consumer-workflow.yml](examples/consumer-workflow.yml) into
your repo at `.github/workflows/update-readme-live-link.yml`:

```yaml
name: Update README Live Link

on:
  push:
    branches: [main]
  workflow_dispatch: # manual "Run workflow" button

permissions:
  contents: write

jobs:
  sync:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: YOUR_ORG/tool-readme-links@v1
      - uses: stefanzweifel/git-auto-commit-action@v5
        with:
          commit_message: "docs: sync live link from repository About section"
```

GitHub has no workflow event for About-section edits, so the workflow runs
on push and on manual dispatch: after changing the About URL, press "Run
workflow" to re-sync the README. Nothing is committed when the rendered
link is already correct.

If this repo lives outside your org, you can also vendor the script and call
it directly; see "Standalone usage" below.

## Inputs

| Input             | Default                             | Description                                                |
| ----------------- | ----------------------------------- | ---------------------------------------------------------- |
| `readme`          | `README.md`                         | File to update                                             |
| `marker`          | `live-link`                         | Marker name in `<!-- NAME:start -->` / `<!-- NAME:end -->` |
| `link-text`       | `View the Live Site`                | Visible text of the link                                   |
| `placeholder-url` | `https://example.com/your-live-url` | URL used when no homepage is set                           |
| `repository`      | `${{ github.repository }}`          | Repo to read the homepage from                             |
| `token`           | `${{ github.token }}`               | Token for the GitHub API                                   |

## Outputs

| Output              | Description                           |
| ------------------- | ------------------------------------- |
| `url`               | URL written (real or placeholder)     |
| `changed`           | `"true"` if the README was modified   |
| `using_placeholder` | `"1"` if the placeholder URL was used |

## Standalone usage

The script is plain bash (`awk`, plus `gh` or `curl`+`jq` for the API):

```bash
GH_TOKEN=$(gh auth token) REPOSITORY=owner/repo ./scripts/update-live-link.sh
```

Environment variables mirror the action inputs: `README_FILE`, `MARKER`,
`LINK_TEXT`, `PLACEHOLDER_URL`, `REPOSITORY`, plus `LIVE_LINK_URL` to inject a
URL directly without calling the API (useful for tests and previews).

## Behavior notes

- Multiple `start`/`end` blocks with the same marker name are all updated.
- Markers inside fenced code blocks (``` or ~~~) are ignored, so marker
  examples in documentation are never rewritten.
- Markers may appear anywhere on their lines (extra indentation or trailing
  text is fine).
- If the API call fails or the repo has no homepage, the placeholder URL is
  used and a warning is printed to stderr. The run does not fail, so a missing
  About URL never breaks CI; check the `using_placeholder` output if you want
  to react to it.
- Missing markers or an end marker before the start marker are hard errors.

## Tests

```bash
bash test/test-update-live-link.sh
```
