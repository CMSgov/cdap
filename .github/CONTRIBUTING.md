# Contribution expectations

The following expectations apply to each PR our internal teams file:

- The PR and branch are named for [automatic linking](https://support.atlassian.com/jira-cloud-administration/docs/use-the-github-for-jira-app/) to the most relevant JIRA issue (for example, `JRA-123 Adds foo` for PR title and `jra-123-adds-foo` for branch name).
- Reviewers are selected to include people from all teams impacted by the changes in the PR.
- The PR has been assigned to the people who will respond to reviews and merge when ready (usually the person filing the review, but can change when a PR is handed off to someone else).
- The PR is reasonably limited in scope to ensure:
  - It doesn't bunch together disparate features, fixes, refactorings, etc.
  - There isn't too much of a burden on reviewers.
  - Any problems it causes have a small blast radius.
  - Changes will be easier to roll back if necessary.
- The PR includes any required documentation changes, including `README` updates and changelog or release notes entries.
- All new and modified code is appropriately commented to make the what and why of its design reasonably clear, even to those unfamiliar with the project.
- Any incomplete work introduced by the PR is detailed in `TODO` comments which include a JIRA ticket ID for any items that require urgent attention.
- If any of the following security implications apply, the PR must not be merged without Stephen Walter's approval. Note any security implications in the Context section of the PR description and add Stephen Walter (GitHub username: SJWalter11) as a reviewer.
  - Adds a new software dependency or dependencies.
  - Modifies or invalidates one or more of our security controls.
  - Stores or transmits data that was not stored or transmitted before.
  - Requires additional review of security implications for other reasons.
