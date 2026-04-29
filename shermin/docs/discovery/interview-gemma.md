# Interview — Gemma Bloomer, Office Manager

**Format:** 30 minutes. ~12 questions across 4 themes. Each one specific and answerable in 2-3 sentences. The "Why we're asking" is for Gemma's benefit so she can see what we're trying to land.

**Aim:** confirm the proposed prescriptive flow matches how Sales Support actually wants to work, and that we know what they need on the screen at each stage.

**Pre-read for Gemma:** `current-state.md` and the proposed pipeline (Lead → Application → Compliance check → Contract → Setup in Stax → Live).

---

## Theme A — Sales Support workflow today

### A1. Walk me through onboarding a retailer end-to-end as you'd describe it today.

*Why we're asking:* to capture the actual sequence of steps, not the idealised one. The proposed v1 stages may merge or split steps you treat separately.

Start from the moment Sales Support hears about a new retailer and end at "they're live in Stax". Don't tidy it up, give us the messy version.

### A2. How does Sales Support find out about a new retailer?

*Why we're asking:* to design the BDM → Sales Support handoff. If it's a Slack DM today, v1 needs to either replicate that signal or change behaviour.

Is it a Slack message from the BDM, an email, a row appearing in the spreadsheet, a tap on the shoulder? Different for different BDMs?

### A3. How many retailers are typically being onboarded at any one time, per Sales Support person?

*Why we're asking:* to size the UI. A "list of 5" view is very different from a "list of 50".

Rough number: if I asked anyone in Sales Support how many retailers they're working through right now, what would they say?

---

## Theme B — Compliance checking

### B1. What does "compliance check" actually consist of?

*Why we're asking:* the proposed v1 has a single "Compliance check" stage. If that stage hides three or four sub-checks, v1 needs to model them.

List the things Sales Support actually verifies before a retailer is allowed through. KYC? FCA permission? Financial fitness? Director checks? Anything else?

### B2. What evidence do you collect, and where does it live today?

*Why we're asking:* to spec file/document handling in v1. We need to know what kinds of documents and how many per retailer.

Specific examples: certificate of incorporation, FCA register screenshot, bank statement, signed agreement. Where are these stored today? Email? Shared drive? SF?

### B3. Who does the compliance sign-off, and is it ever a different person from whoever started the check?

*Why we're asking:* to decide whether v1 needs a "checked by" and a separate "approved by" field, or just one.

Is it the same Sales Support person all the way through, or does someone else (Compliance, you, Tony) tick the final approval?

### B4. What happens if a retailer fails compliance?

*Why we're asking:* the proposed v1 only has "live" or "lost". If "failed compliance, parked" is a real state, we need it.

Do you ever park a retailer for months and pick it back up? Or is failed compliance terminal? How do you keep track of the parked ones?

---

## Theme C — Setup in Stax mechanics

### C1. When a retailer is ready to go live, what specifically gets configured in Salesforce?

*Why we're asking:* the proposed v1 pushes Account + Contact into SF. We need to know if that's enough or if it's missing fields Sales Support relies on.

Walk through the SF record. What fields are filled in, by hand or otherwise, before the retailer is live?

### C2. What gets configured in Stax itself, and who does it?

*Why we're asking:* to confirm the boundary between "what the CRM does" and "what stays manual".

Lender routing, waterfall logic, commission, product set, branding. Who configures each of these, and how long does it take?

### C3. Where in this process is it most likely to go wrong?

*Why we're asking:* to make sure v1 puts a guardrail at the right step rather than at every step.

Honestly, if you had to pick one moment in setup where things get fluffed up, which is it? What's the typical mistake?

---

## Theme D — Pain points and exception cases

### D1. Tell me about a recent retailer that took much longer than expected to onboard. Why?

*Why we're asking:* a real-world story tells us where the process actually breaks. Plural anecdotes are even better.

What stage did they get stuck at, and what was it that finally moved them?

### D2. What about a retailer that went quiet for months and came back? How do you handle reactivation?

*Why we're asking:* the proposed v1 doesn't model reactivation explicitly. If it happens often enough we need a path for it.

Do they restart from scratch, or do you pick up where they left off? Is the original SF Account reused, or do you make a new one?

### D3. What's the one thing about the current process that makes you want to throw a stapler?

*Why we're asking:* the strongest signal for what v1 must fix is whatever annoys Gemma the most.

Vent freely. Whatever you say here, we'll prioritise.

---

## Decisions Gemma owns

- **Compliance check sub-stages.** Whether v1 models compliance as one stage with multiple required documents, or as several sub-stages (KYC, FCA, financial fitness, sign-off).
- **Document storage.** Are documents attached to the retailer record in the CRM, or stored elsewhere with just a link?
- **"Checked by" vs "approved by".** Whether these are the same person or two roles.
- **Failed-compliance state.** Whether "on hold" is a real status, distinct from "lost", and how long retailers can sit there.
- **Reactivation path.** Restart from scratch or resume the same record.
- **Operational artefacts to share** (please bring or send these before the interview):
  - The current onboarding tracking spreadsheet.
  - Any onboarding checklist Sales Support uses, even if informal.
  - A sample of compliance evidence (anonymised) so we can see the document types.
  - Any training docs Sales Support uses for new starters in the team.

## After the interview

Update `diff-vs-proposed-v1.md` with confirmed/refuted assumptions, and feed the document-handling decisions into the Workstream B data-model.
