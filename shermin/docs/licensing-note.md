# AGPL-3.0 licence implications for the Shermin CRM fork

**For:** Tony Lilley (Commercial Director), and whoever does Shermin's legal review (internal or external counsel).
**Author:** Engineering, Phase 0 discovery.
**Status:** Draft for legal sign-off. Not legal advice.

## What we are doing

We plan to fork [Twenty CRM](https://github.com/twentyhq/twenty), a Salesforce-style open-source CRM, and self-host it on AWS (eu-west-2) for internal use by Shermin Finance and Homeserve staff and contractors. Most customisation will be via Twenty's "Twenty Apps" SDK (the documented extension point), with a small amount of direct modification to the core if absolutely necessary.

Our fork lives at `Shermin-Finance-Ltd/twenty-shermin`. It is private. We are not redistributing the software, we are not selling access to it, and it will not be exposed to retailers or the public.

## What AGPL-3.0 actually requires

Twenty is licensed under [AGPL-3.0](https://www.gnu.org/licenses/agpl-3.0.html), with a small number of files (typically SSO connectors and premium "enterprise" features) under a separate commercial licence. This is the common "open core" pattern.

AGPL is GPL with one extra clause. The core obligation: **if you distribute the software, or modify it and offer it as a network service to users, you must make the corresponding source code available to those users on the same licence terms.**

The clause that distinguishes AGPL from GPL is Section 13:

> "if you modify the Program, your modified version must prominently offer all users interacting with it remotely through a computer network ... an opportunity to receive the Corresponding Source of your version ... at no charge"

In plain English:

1. If you ship binaries to anyone, you must ship source.
2. If you let anyone outside your organisation interact with a modified version over a network, you must offer them the source too.
3. You cannot mix AGPL code with proprietary code in a way that lets you avoid (1) or (2).

## Whether that bites for our use case

Three tests:

**(a) Are we distributing modified Twenty?**
No. The fork is private. Binaries stay inside our AWS account. We are not shipping Docker images, tarballs, or source to any third party. AGPL's distribution triggers (Sections 4–6) do not fire.

**(b) Are we offering a network service to users outside the organisation?**
No, with one caveat. The CRM will be accessed by Shermin and Homeserve staff and by contractors working on Shermin's behalf. The AGPL FSF guidance and the broad consensus reading (the FSF's own [AGPL FAQ](https://www.gnu.org/licenses/gpl-faq.html#UnreleasedMods) and most legal commentary) is that **internal use within a single organisation is not "conveying" or "providing to the public"**, and Section 13 does not trigger. The grey area is contractors. If a contractor has workspace access for the duration of a piece of work and is acting on Shermin's behalf, they are generally treated as part of the organisation (the same way a temporary employee would be). If we ever gave access to a third party who was a customer or partner in their own right — for example, a retailer or a lender — that would be a different question.

**(c) Are we statically linking AGPL code into proprietary Shermin code?**
No. Our extension is a Twenty App, which is the documented extension point. The boundary is the Twenty Apps SDK. This is a clean process boundary, not static linking, and it is the model the upstream project actively encourages. If we ever did need to fork the core itself and merge proprietary code into it, those modifications would themselves become subject to AGPL, but that is fine because we are not distributing them.

## Conclusion

For the planned internal-only deployment, **AGPL-3.0 is almost certainly fine**. The risk surface is narrow:

- We are not distributing the software.
- We are not offering it to users outside Shermin / Homeserve.
- Our modifications sit behind the documented extension SDK.

The realistic future risk is scope creep. **If at any point Shermin wanted to expose the CRM directly to external retailers, lenders, or customers — i.e. give them logins to our Twenty instance — the analysis changes** and we would need to either (a) publish our modified source under AGPL, or (b) buy a commercial licence from the upstream Twenty Inc., or (c) keep our modifications strictly inside Twenty Apps so the "modified version" point becomes weaker. That is a future decision, not a v1 decision.

## What we would need to do if we ever offered it externally

If a future version of this product is exposed to any user outside the Shermin / Homeserve perimeter:

- Publish the source of our modifications to those external users (a public Git repo, or an in-app "Download source" link, both are accepted).
- Add a "View source" notice in the product UI, pointing at where the source lives.
- Keep all upstream copyright and licence headers intact in the published source.
- Match the upstream version closely enough that we can credibly publish a useful diff, rather than a heavily diverged fork.

None of this is hard. It just needs to be a deliberate choice, not an accident.

## What we should do now

A short checklist for v1:

- [ ] **Legal sign-off.** Tony to review this memo. If comfortable, sign off in writing. If uncertain, escalate to external counsel (a 30-minute review is enough). Cost: small.
- [ ] **Document the licence position.** Add a short paragraph to the new repo's `README.md` and to `SHERMIN.md` stating: "This is a private fork of Twenty (AGPL-3.0). Internal Shermin / Homeserve use only. Not redistributed. Not exposed to external users."
- [ ] **Leave the upstream `LICENSE` file untouched** in the fork root.
- [ ] **Do not strip Twenty's copyright headers** from any file we copy or adapt. Add Shermin's copyright alongside, do not replace.
- [ ] **Track the licence boundary in code review.** If a PR proposes to expose any Twenty endpoint to a non-Shermin user, that PR must explicitly reference this memo and get a sign-off.
- [ ] **Revisit this memo if we ever share the URL externally**, even with a single retailer or pilot customer. That is the trigger to escalate to legal again.

## Honest caveats

- This is engineer-written, not lawyer-written. Treat it as a starting point for a 30-minute legal review, not as a finished legal opinion.
- The internal-use exemption is widely accepted in industry practice and consistent with the FSF's own commentary, but it has not been heavily tested in UK or EU courts. The risk of a successful AGPL enforcement action against a company doing what we are doing is, in practice, very low. It is not zero.
- The contractor boundary is the grey bit. If Shermin uses a large or rotating pool of third-party contractors, or contractors who themselves work for direct competitors of Twenty Inc., it would be worth being more cautious.
- Twenty is a commercially backed open-source project (Twenty Inc.). If we ever wanted certainty, the cleanest answer is a commercial licence from them. For internal use only, this is unlikely to be needed.

## Sources

- AGPL-3.0 full text: https://www.gnu.org/licenses/agpl-3.0.html
- Plain-English explainer: https://choosealicense.com/licenses/agpl-3.0/
- FSF GPL FAQ (covers internal use and modified versions): https://www.gnu.org/licenses/gpl-faq.html
- Twenty `LICENSE` file in our fork: `~/Dev/twenty-shermin/LICENSE`
- Twenty's own licence guidance: https://github.com/twentyhq/twenty/blob/main/LICENSE
