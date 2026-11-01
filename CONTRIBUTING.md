<!--
  - SPDX-FileCopyrightText: 2026 Euro-Office contributors
  - SPDX-License-Identifier: AGPL
-->

# Contributing to Euro-Office

Thanks for wanting to contribute to Euro-Office. That's great!

Euro-Office is open source and developed in public. We welcome contributions from anyone - individuals, companies, public organizations and non-profits - as long as you follow our [Code of Conduct](CODE_OF_CONDUCT.md).

This file is the organization-wide default. The full contribution process - design rules, coding guidelines, and the issue-first workflow - is documented in the [DocumentServer Contribution Guidelines][devprocess]. Individual repositories may add their own `CONTRIBUTING.md` with component-specific details.

## Licensing and sign-off

Euro-Office is licensed under the [AGPLv3][agpl]. Contributions must be compatible with it.

Commits are required to be signed off. By adding a `Signed-off-by` trailer (`git commit -s`) you certify the [Developer Certificate of Origin][dco] - that you wrote the contribution or otherwise have the right to submit it under the project's license.

## Reviews and merging

Human review time should go where it matters: community contributions, risky areas, and anyone who asks for it. Maintainers are the members of the [Euro-Office GitHub organization](https://github.com/orgs/Euro-Office/people).

* Whoever merges is responsible for the change. "The AI approved it" is no excuse.
* Humans decide: the AI review is input, a maintainer makes the call, except for [auto-merges](#auto-merge).
* A human approval always means a human actually reviewed the change.
* Risk counts, not size: three lines in file saving can matter more than a hundred in an admin view.
* Anyone can ask for a human review, no reason needed.

Every pull request needs approval from at least one maintainer, except the low-risk changes listed under [AI review only](#ai-review-only).

### Always require a human review

* Dependencies: new packages, manual runtime dependency changes
* Licensing: legal text, upstream changes, differently licensed components
* Security and privacy: authentication, JWT, new network calls, changed defaults
* Document core: x2t converters, format readers and writers, co-editing
* Build and release: CI workflows, build and release scripts
* Governance: CODEOWNERS, branch protection, contribution and AI policies
* Contributions from first-time or external contributors

### AI review only

Maintainers may merge their own pull request after reviewing it themselves, with only an AI review on top, if it touches nothing from the list above. Add the `ai-review-only` label so this stays visible.

* Docs, typos and translation syncs, but not legal text, privacy notices or new string keys
* Tests that add coverage, never skipping or deleting a failing test
* Formatting with the configured linter, no logic change mixed in
* Local dev tooling, but not CI workflows
* Trivial fixes and UI bug fixes outside the document core, with a regression test
* Refactors in code covered by existing tests
* Small UI features behind a default-off setting
* Clean backports of an already merged fix

### Auto-merge

Renovate and Dependabot updates, except major versions, merge automatically once CI passes. Renovate also waits until a release is 3 days old.

## AI-assisted contributions

Euro-Office allows contributions made with the help of AI tools. You are the author of everything you submit - AI assistance does not change that responsibility.

* **Disclosure:** Declare AI tool use in the PR description and add an `Assisted-by: AGENT_NAME:MODEL_VERSION` git trailer to each affected commit.

* **Accountability:** You must be able to explain, defend, and modify every line you submit. If a reviewer asks why something works a certain way, "the AI wrote it" is not an answer.

* **Communication:** PR descriptions, review comments, and issue reports must be written in your own words. This applies throughout the review process - passing reviewer feedback to an AI and posting whatever comes out is not acceptable.

* **Quality:** AI output must be quality assured by the human, i.e. reviewed, cleaned up, and tested before submission. New features must be tested on a live instance by you, not by an agent. Code that has never been executed, or that shifts debugging work onto maintainers, will not be accepted.

* **Licensing:** Ensure AI-generated code contains no material incompatible with the license of the repository you are contributing to.

For the full policy including autonomous agent rules, security reports, and beginner issues, read the [AI Contribution Policy][aipolicy].

[devprocess]: https://github.com/Euro-Office/DocumentServer/blob/main/CONTRIBUTING.md
[agpl]: https://www.gnu.org/licenses/agpl-3.0.en.html
[dco]: https://developercertificate.org/
[aipolicy]: https://github.com/Euro-Office/.github/blob/main/AI_POLICY.md
