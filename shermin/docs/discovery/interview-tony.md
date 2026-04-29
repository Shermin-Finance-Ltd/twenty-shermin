# Interview — Tony Lilley, Commercial Director

**Format:** 30 minutes, conversational. ~12 questions in 4 themes. Each question is one specific thing, easily answered in 2-3 sentences. The "Why we're asking" line is for Tony to read so he understands what we're trying to nail down, not a script for the interviewer.

**Aim:** confirm whether the proposed v1 actually helps BDMs sell more, surfaces the right pipeline metrics, and works for the BDM mix (self-employed and PAYE).

**Pre-read for Tony:** the headline v1 plan in `SHERMIN.md` and `current-state.md`.

---

## Theme A — Current pipeline visibility

### A1. What pipeline view do you actually look at today?

*Why we're asking:* to confirm whether the v1 dashboard needs to reproduce something Tony already uses, or whether it's a clean-slate build.

Tell us, on a normal Monday morning, what do you open to see how the retailer pipeline is doing? Spreadsheet, Salesforce report, a Slack scroll, all of the above?

### A2. What's the one number you wish you could see at a glance and currently can't?

*Why we're asking:* to make sure the v1 dashboard headline metric is the one Tony actually wants, not one we guessed at.

If the CRM only had room for one big number on the home screen for you, what would it be? Retailers in flight? Conversion rate? Time-to-live?

### A3. How do you currently know a retailer has stalled?

*Why we're asking:* to decide whether v1 needs an automatic "stalled" indicator (no movement for N days) or whether you'd rather just see the dates and judge for yourself.

Walk me through a recent example: a retailer that went quiet. How did you find out? Did someone tell you, did you spot it, or did it surface only when you asked?

---

## Theme B — BDM workflow and adoption

### B1. What would actually get a BDM to use this CRM rather than just emailing you?

*Why we're asking:* this is the single biggest risk to v1. If BDMs don't enter their leads, the pipeline view is fiction.

Be honest: is there anything realistic we can do in v1 that would make the average BDM open the CRM at least once a day? Or do we need to accept that the pipeline only becomes accurate from the Sales Support handoff onwards?

### B2. Should self-employed BDMs see other BDMs' retailers?

*Why we're asking:* to make a v1 access-rule decision. Default-closed (each BDM only sees their own) is safer but may stop useful collaboration.

What's your instinct on visibility between BDMs? All-can-see-all, or each-sees-only-their-own, or something in between?

### B3. Does the BDM ever share a retailer with another BDM?

*Why we're asking:* if shared retailers exist, the data model needs `Retailer.owners` (multiple) not `Retailer.owner` (single).

Does it ever happen that two BDMs are both involved with the same retailer (e.g. one sourced it, another covers the geography)? How do you handle commission then?

### B4. Where does a BDM stop and Sales Support take over?

*Why we're asking:* to confirm or correct the proposed role boundary "BDM owns Lead → Application, Sales Support owns Compliance check → Live".

Is the handover at "we've agreed in principle, now do the paperwork", or earlier, or later? Where do you think it should be, and where does it actually sit today?

---

## Theme C — Commercial KPIs and reporting

### C1. What stage-conversion rates do you need to report on?

*Why we're asking:* to confirm the metrics v1 must produce out of the box. Stage-conversion is cheap if we know up front, expensive to retrofit.

Lead → Application, Application → Compliance, Compliance → Live. Are those the conversion rates you care about, or do you measure something else?

### C2. What's the right time window for those conversion rates?

*Why we're asking:* to spec the default reporting period and any rolling-window logic.

Monthly? Quarterly? Rolling 90 days? Different windows for different metrics?

### C3. Is BDM-by-BDM performance reporting in scope for v1?

*Why we're asking:* there's a meaningful difference between "Tony can see all BDMs side by side" and "each BDM sees their own". Both are doable, but they're different builds.

Do you want a leaderboard in v1, or is that a later thing? If yes, who sees it: just you, you and Gareth, or all the BDMs?

---

## Theme D — Self-employed vs PAYE differences

### D1. Where does the process actually differ between a self-employed BDM and a PAYE BDM?

*Why we're asking:* to know if v1 needs a `BDM.type` field that drives different UI or stage rules, or whether they can share one workflow.

Practically, what does a self-employed BDM do differently to a PAYE BDM in the lead-to-live journey? Anything material, or is it purely a contract/comms-channel difference?

### D2. Is there a difference in what each type of BDM should be allowed to see or do in the system?

*Why we're asking:* feeds the role/permission spec for Workstream B.

Specific examples welcome. E.g. should a self-employed BDM be able to see retailer commercial terms? Should they be able to edit the pipeline stage themselves, or only suggest a move?

### D3. Onboarding a new BDM: would you want this CRM to track that too?

*Why we're asking:* to scope-check. Self-employed BDMs themselves get onboarded, and that's arguably another pipeline. We're proposing it's out of scope for v1, but want a sanity check.

Is BDM-onboarding a problem the CRM should help with later, or is that a totally separate thing handled by Gemma's team?

---

## Decisions Tony owns

These are the v1 design choices that we'd like Tony to sign off (or push back on) by the end of the discovery round:

- **BDM visibility model.** All-can-see-all, each-sees-only-their-own, or hybrid (BDM sees own, Tony/Gemma/Admin see all).
- **Single vs multi-owner retailer.** Whether `Retailer.owner` is one BDM or potentially several.
- **Role boundary for BDM → Sales Support handoff.** Confirm "Lead and Application = BDM, Compliance check onwards = Sales Support", or move the line.
- **Headline pipeline metrics for the v1 dashboard.** Top 3, with their reporting windows.
- **BDM leaderboard in v1, or v2 only.**
- **Self-employed vs PAYE: one workflow or two.**
- **BDM onboarding pipeline: in scope for the CRM eventually, or never.**

## After the interview

Mark each decision above with Tony's answer and feed the deltas into `diff-vs-proposed-v1.md` and the data-model spec.
