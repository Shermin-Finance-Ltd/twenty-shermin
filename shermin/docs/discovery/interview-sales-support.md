# Interview — Sample Sales Support team member

**Format:** 30 minutes. ~12 questions in 4 themes. They're the power user of the CRM, so depth matters here. Each question is specific and answerable in 2-3 sentences. The "Why we're asking" line is for them to read.

**Aim:** ground-truth the proposed prescriptive flow against how Sales Support actually does the work, and decide whether v1's required-fields-per-stage is enough or whether we need a Trello-style checklist sooner than planned.

**Pre-read:** the proposed pipeline (Lead → Application → Compliance check → Contract → Setup in Stax → Live) and the role boundary (BDM owns Lead → Application; Sales Support owns Compliance check → Live). Five minutes' verbal setup at the start of the interview is fine instead of a pre-read.

---

## Theme A — Walk me through a real onboarding

### A1. Pick a retailer you've onboarded recently. What was the first thing you did when you knew they were yours?

*Why we're asking:* the entry point to your work is the BDM → Sales Support handoff. We want to see what triggered you and what info you started with.

### A2. From that first action, walk me through every step you took. Don't tidy up, give us the real version.

*Why we're asking:* to map the actual sequence against the proposed v1 stages. Anywhere your real flow diverges from "Application → Compliance check → Contract → Setup in Stax → Live" matters.

Take your time. Skip nothing, even small admin tasks.

### A3. How long did that retailer take from your first action to going live?

*Why we're asking:* to set realistic time-in-stage expectations and know what counts as "stuck".

Was that typical? What's a fast one, what's a slow one?

---

## Theme B — Compliance check

### B1. What documents do you collect from a retailer to clear compliance?

*Why we're asking:* to spec the document checklist on the Compliance check stage. Required fields are only useful if we know what's required.

Full list, please. Certificate of incorporation, FCA status check, bank details, anything else.

### B2. Where do those documents end up living?

*Why we're asking:* to decide whether v1 attaches files directly to the retailer record, or links out to wherever you keep them today.

Email folder, shared drive, Salesforce attachments, somewhere else?

### B3. Has there ever been a retailer where compliance was fine but something else made you pause?

*Why we're asking:* to test whether "Compliance check" should actually be two stages: a documentary check and a judgement call.

E.g. their FCA status was clean but you had a concern about something else, like a director with a previous failed business.

### B4. Who has the final yes/no on compliance?

*Why we're asking:* to model the approval step. If it's always you, one field is enough. If it goes to Gemma or Tony, we need a separate "approved by" field.

Does it stop with Sales Support, or does it always go up?

---

## Theme C — Setup in Stax

### C1. When a retailer hits "ready to go live", what's the first thing you configure?

*Why we're asking:* to confirm the order of operations and where the SF Account / Contact creation slots in.

Do you start in Salesforce, in Stax, or somewhere else?

### C2. What fields do you have to enter manually in Salesforce?

*Why we're asking:* the proposed v1 will push some fields into SF automatically. We need to know which ones, so the manual list shrinks accordingly.

The full list. We'll work out from this which are easy for the CRM to populate and which stay manual.

### C3. What's the most error-prone bit of Stax configuration?

*Why we're asking:* to put the v1 guardrail on the right step. If lender routing is the easy bit but commission setup catches people out, we know where to focus.

Specific examples welcome. "I've forgotten to tick X on a retailer about three times this year" is exactly what we want to hear.

### C4. Does the BDM ever do part of this configuration today?

*Why we're asking:* if the answer is yes, the proposed role boundary "Sales Support owns Compliance check → Live" is wrong, and v1 needs to give some Stax-config rights to BDMs.

Or do they only ever ask questions, and you do all the actual config?

---

## Theme D — Checklists vs required fields

### D1. The v1 plan is to enforce stage transitions by required fields, not a Trello-style checklist. Would required fields alone actually work for you?

*Why we're asking:* this is the single biggest v1 vs v2 scoping question. If Sales Support need a checklist immediately, we have to bring it forward.

Or are required fields plus a clear stage status enough to keep things on track?

### D2. Are there steps in your work today that don't fit a "field has a value" model?

*Why we're asking:* some checklist items aren't data, they're actions ("I rang the retailer to confirm bank details"). We need to know if those exist.

E.g. "I phoned them to confirm the contact", "Tony approved the commercial terms verbally". Things that aren't really fields.

### D3. If you could have one feature in v1 that the plan doesn't currently include, what would it be?

*Why we're asking:* a sanity check. The most useful feature is often the one we haven't thought of.

No filter, just say.

---

## Validation tests

Once v1 is in staging, walk through these scenarios with the interviewee. The CRM should handle each one cleanly:

1. **Happy path.** Onboard a new retailer end-to-end, BDM submits a lead, Sales Support pushes them through every stage, retailer goes live, SF Account + Contact appear in Salesforce.
2. **Failed compliance, parked.** Retailer fails a document check. Park them for 3 months. Pick them back up. Confirm the record is still where you left it and the missing document is still flagged.
3. **Retailer goes quiet between Application and Compliance.** No movement for 30 days. Confirm the system flags it and that you can record an "on hold" or equivalent state.
4. **Wrong handoff.** A BDM hands over a retailer where compliance is clearly going to fail (e.g. no FCA permission). Confirm Sales Support can reject and bounce back to the BDM without losing the record.
5. **Reactivation.** A retailer that went lost 6 months ago comes back. Reuse the original record vs create a new one: which behaviour does the system support, and which does the team want?
6. **Two retailers same group.** Two retailers under one parent company. Confirm whether the data model handles this and whether your team needs it in v1.
7. **BDM error.** A BDM puts the wrong information at the Application stage. Confirm Sales Support can correct it without bouncing the record back, or that bouncing back is the preferred flow.

## After the interview

Run the validation scenarios above against the v1 staging build. Anything that fails or is awkward becomes a v1 amendment rather than a v2 wishlist item.
