# README Live Link

**One URL in About. Zero drift in your README.**

Syncs your README's live link with your repository's **About** URL, on
demand. Ships as a composite GitHub Action (`action.yml`) and a standalone
bash script (`scripts/update-live-link.sh`). No About URL set? The same
link markup is written with a placeholder URL, so the README looks
identical.

## Live Site

<!-- live-link:start -->

[View the Live Site](https://example.com/your-live-url)

<!-- live-link:end -->

(Maintained by this repo's own
[workflow](.github/workflows/update-readme-live-link.yml).)

## Quick Run

From inside this repo, sync another repo's README in one command:

```bash
README_FILE=/path/to/other-repo/README.md \
  REPOSITORY=owner/other-repo \
  ./scripts/update-live-link.sh
```

Example, updating a sibling checkout of `documind`:

```bash
README_FILE=../documind/README.md REPOSITORY=DevArtsLab/documind ./scripts/update-live-link.sh
```

`README_FILE` points at the other repo's README; `REPOSITORY` is the
`owner/name` to read the About URL from. Uses `gh` when installed, so a
logged-in `gh` needs no token setup.

## Setup

1. Put markers in your README:

   ```markdown
   <!-- live-link:start -->
   <!-- live-link:end -->
   ```

   Everything between them is managed by the tool.

2. Copy [examples/consumer-workflow.yml](examples/consumer-workflow.yml) to
   `.github/workflows/update-readme-live-link.yml` and replace `YOUR_ORG`:

   ```yaml
   name: Update README Live Link

   on:
     workflow_dispatch: # "Run workflow" button, any branch
     repository_dispatch: # optional external trigger

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

3. Set the URL in the repo's About section, then press "Run workflow".
   Commits only when the rendered link actually changed.

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

```bash
GH_TOKEN=$(gh auth token) REPOSITORY=owner/repo ./scripts/update-live-link.sh
```

Env vars mirror the inputs: `README_FILE`, `MARKER`, `LINK_TEXT`,
`PLACEHOLDER_URL`, `REPOSITORY`. Set `LIVE_LINK_URL` to skip the API.

## Notes

- Multiple marker blocks are all updated; markers inside code fences are
  left alone.
- Missing markers or reversed marker order are hard errors. API failure or
  no homepage: placeholder is written, warning on stderr, run still
  succeeds — check `using_placeholder` to react.

## Tests

```bash
bash test/test-update-live-link.sh
```

## Data handling

Collects nothing. Reads the repository `homepage` field via the GitHub API
inside the Actions runner, writes the link to the README, exits. No data
leaves GitHub infrastructure.

## Support

[Open an issue](https://github.com/DevArtsLab/tool-readme-links/issues).

## License

MIT. See [LICENSE](LICENSE).

## Credits

Built by [DevArts Lab](https://github.com/DevArtsLab).
