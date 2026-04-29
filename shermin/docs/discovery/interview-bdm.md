# Interview — Sample BDM

**Format:** 20 minutes. BDMs are time-poor and field-based, so keep it tight. ~10 questions in 3 themes. Each one specific and answerable in 2-3 sentences.

**Aim:** sanity-check that the proposed CRM will actually get used by a BDM, save them time, and make their pipeline visible to Tony in a way they're comfortable with. Talk to ideally one self-employed and one PAYE BDM if possible.

**Pre-read:** none expected. Talk them through the proposal verbally at the start (one minute) so they have context.

---

## Theme A — Lead intake and handoff

### A1. Where do your retailer leads come from, day to day?

*Why we're asking:* to understand whether v1 needs a structured lead-source field, free text, or nothing.

Inbound calls? Existing relationships? Trade events? Cold approach? Roughly what's the mix?

### A2. How do you track who you're talking to today, before they're a deal?

*Why we're asking:* to know what we're competing with. If it's a notebook, the bar for v1 is "easier than a notebook". If it's a spreadsheet you already love, the bar is higher.

Phone notes, spreadsheet, your head, Salesforce, something else?

### A3. When a retailer is ready for Shermin to onboard, how do you currently hand them over to Sales Support?

*Why we're asking:* to design the BDM → Sales Support handoff in v1. We want to replace the current channel, not add to it.

Slack message? Email? Phone call? Do you fill anything in first, or just fire off the contact details and Sales Support takes it from there?

### A4. What's the one thing you wish Sales Support always asked you for at the handoff but doesn't?

*Why we're asking:* this surfaces a required field for the Application stage that we'd otherwise miss.

Or the other way around: what do they always come back to ask you that you wish you'd handed over up front?

---

## Theme B — Information needs through the pipeline

### B1. Once a retailer is in Sales Support's hands, what do you wish you could see about how they're doing without having to ask?

*Why we're asking:* this defines the BDM's read-only dashboard view of their own pipeline post-handoff.

Specific examples: "have they signed the contract", "did compliance pass", "are they live yet", "what's the latest note from Sales Support".

### B2. Do you ever lose visibility on a retailer and only find out months later they did or didn't go live?

*Why we're asking:* if yes, automated status updates back to the BDM are a v1 must-have, not a nice-to-have.

Tell me about a recent example.

### B3. Once a retailer is live, what do you want to see about their performance?

*Why we're asking:* to scope whether the CRM surfaces application volume / commission per retailer to the BDM, or whether they keep using whatever they use today (likely Stax / SF reports).

Application volumes? Commission earned? Lender outcomes? Or do you just check Stax for that?

---

## Theme C — Mobile, desktop and where you actually work

### C1. Where are you when you're working with retailers, physically?

*Why we're asking:* to decide how much v1 needs to work on a phone or tablet vs being a desktop tool.

Office, home, in the car between retailer visits, at the retailer's site?

### C2. If the CRM only worked properly on desktop, would that be a dealbreaker?

*Why we're asking:* mobile-first costs more to build than desktop-only. If most BDMs are at a desk anyway, it's not worth it for v1.

Honest answer: would you actually use it on a phone, or are you always near a laptop when you'd be inputting things?

### C3. What's the longest task you'd be willing to do on the phone vs sitting at a laptop?

*Why we're asking:* helps us scope which tasks (quick status update, full new-retailer entry) need mobile parity vs desktop-only.

Adding a quick note, OK on a phone? Filling in a 10-field form, no thanks?

---

## Decisions the BDM informs

These don't need BDM sign-off, they calibrate the v1 design:

- **Lead source field.** Free text, structured dropdown, or absent altogether in v1.
- **Handoff form.** What fields are required at "Application → Compliance check" stage transition.
- **Read-only post-handoff view.** What information BDMs see about retailers Sales Support has taken over.
- **Notification model.** Whether BDMs get pushed updates (email, in-app) or only see status when they log in.
- **Mobile priority.** Desktop-first with a mobile-friendly read view, or mobile-parity from day one.
- **Live-retailer reporting.** Whether commission and volume show up in the CRM or stay in Stax/SF reports.

## After the interview

Capture verbatim quotes for any "must-have" or "dealbreaker" answers and feed them into `diff-vs-proposed-v1.md`. If two BDMs are interviewed (self-employed and PAYE), note where they answered differently.
