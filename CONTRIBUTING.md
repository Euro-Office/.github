<!--
  - SPDX-FileCopyrightText: 2026 Euro-Office contributors
  - SPDX-License-Identifier: AGPL
-->

# Contributing to Euro-Office

Thanks for wanting to contribute to Euro-Office. That's great!

Euro-Office is open source and developed in public. We welcome contributions from anyone - individuals, companies, public organizations and non-profits - as long as you follow our [Code of Conduct](CODE_OF_CONDUCT.md).

This file is the organization-wide default. The full contribution process - design rules, coding guidelines, the issue-first workflow, and the review and merge process - is documented in the [DocumentServer Contribution Guidelines][devprocess]. Individual repositories may add their own `CONTRIBUTING.md` with component-specific details.

## Licensing and sign-off

Euro-Office is licensed under the [AGPLv3][agpl]. Contributions must be compatible with it.

Commits are required to be signed off. By adding a `Signed-off-by` trailer (`git commit -s`) you certify the [Developer Certificate of Origin][dco] - that you wrote the contribution or otherwise have the right to submit it under the project's license.

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
