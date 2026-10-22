#!/usr/bin/env bash
# Write .releaserc.yml for semantic-release (no CHANGELOG file).
set -euo pipefail
cat > .releaserc.yml <<'EOF'
branches:
  - main
tagFormat: "v${version}"
plugins:
  - "@semantic-release/commit-analyzer"
  - "@semantic-release/release-notes-generator"
  - - "@semantic-release/github"
    - successComment: |
        :tada: This ${issue.pull_request ? "PR is included" : "issue has been resolved"} in version ${nextRelease.version} :tada:

        The release is available on [GitHub release](<github_release_url>).
      failComment: false
      releasedLabels:
        - released
      assets: []
EOF
