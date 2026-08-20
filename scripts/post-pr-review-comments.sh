#!/usr/bin/env bash
# Delete prior scankit inline review comments and post a new review on the PR.
# Usage: post-pr-review-comments.sh <review-comments.json>
# Env: GITHUB_REPOSITORY, PR_NUMBER, HEAD_SHA (required); GH_TOKEN via gh auth.
set -euo pipefail

COMMENTS_JSON="${1:?review-comments.json required}"
MARKER='<!-- scankit-inline -->'

REPO="${GITHUB_REPOSITORY:?GITHUB_REPOSITORY required}"
PR="${PR_NUMBER:?PR_NUMBER required}"
HEAD="${HEAD_SHA:?HEAD_SHA required}"

if [[ ! -f "$COMMENTS_JSON" ]]; then
  echo "Missing $COMMENTS_JSON; skip inline review"
  exit 0
fi

COUNT="$(python3 -c 'import json,sys; print(len(json.load(open(sys.argv[1])).get("comments") or []))' "$COMMENTS_JSON")"
if [[ "$COUNT" -eq 0 ]]; then
  echo "No inline review comments to post"
  exit 0
fi

echo "Removing previous scankit inline review comments on PR #${PR}..."
while IFS= read -r cid; do
  [[ -z "$cid" ]] && continue
  gh api -X DELETE "repos/${REPO}/pulls/comments/${cid}" 2>/dev/null || true
done < <(
  gh api --paginate "repos/${REPO}/pulls/${PR}/comments" \
    --jq ".[] | select(.body | contains(\"${MARKER}\")) | .id" 2>/dev/null || true
)

REVIEW_PAYLOAD="$(mktemp)"
python3 - "$COMMENTS_JSON" "$HEAD" "$REVIEW_PAYLOAD" <<'PY'
import json, sys
comments_file, head, out = sys.argv[1], sys.argv[2], sys.argv[3]
data = json.load(open(comments_file))
comments = data.get("comments") or []
payload = {
    "commit_id": head,
    "event": "COMMENT",
    "body": f"<!-- scankit-inline --> scankit posted **{len(comments)}** inline finding(s) on this diff. See the sticky summary comment and Code Scanning for the full set.",
    "comments": comments,
}
json.dump(payload, open(out, "w"), indent=2)
PY

echo "Posting inline review with ${COUNT} comment(s)..."
if gh api --method POST "repos/${REPO}/pulls/${PR}/reviews" --input "$REVIEW_PAYLOAD"; then
  echo "Inline PR review comments posted"
else
  echo "::warning::scankit: failed to post inline PR review (some lines may be outside the PR diff)"
  exit 0
fi

rm -f "$REVIEW_PAYLOAD"
