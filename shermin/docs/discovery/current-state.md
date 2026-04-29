# Current state — retailer onboarding at Shermin

This is what we think we know about how a retailer gets onboarded today, before interviews. Anything not directly confirmed by Barney is flagged **(inferred, confirm)**. The point of the four interviews is to either tick these off or rewrite them.

## The shape of the process today

A new retailer typically comes in through a BDM, either self-employed or PAYE, who has had a commercial conversation and got the retailer interested in joining the Shermin panel. From that point through to the retailer being "live" (i.e. able to run applications through Stax), the work passes through several hands: the BDM, Sales Support, and at some point Compliance, with Tony and Gemma overseeing the commercial and operational sides respectively.

There is no single system of record for that journey today. The pipeline lives across:

- **A spreadsheet** (Excel or Google Sheets) tracking retailers in flight. **(inferred, confirm)** — Barney has described pipeline visibility as essentially spreadsheet-driven, but we have not seen the file or confirmed who owns it.
- **Slack DMs and channels** for the day-to-day chat about a given retailer (chasing documents, flagging compliance issues, "have we heard back from X"). **(inferred, confirm)**
- **Email** for anything formal: contract issuance, signed agreements, compliance evidence coming back from the retailer.
- **Salesforce** as the production system once a retailer is live. Account and Contact records exist in SF for live retailers, and ongoing application activity through Stax is tied back to the SF Account.
- **Stax** itself, where lender routing, product configuration and any retailer-specific commercial terms get configured.

So the journey is: commercial conversation, paperwork chase, compliance check, contract signed, manual setup in SF + Stax, retailer goes live. Tracked across spreadsheet + Slack + email until live, then SF + Stax once live.

## Roles, as we currently understand them

- **BDM** owns the retailer relationship up to the point where a commercial agreement is in principle. They source the lead, qualify it, and get the retailer to the point where Shermin formally onboards them. Some BDMs are self-employed (effectively external agents), some are PAYE (Shermin staff). **(inferred, confirm)** — we believe the workflow is broadly the same for both, but commission, visibility and oversight may differ.
- **Sales Support**, run out of the office under Gemma, picks up from the BDM and runs the operational onboarding: gathering KYC and compliance documents, pushing through the contract, configuring the retailer in Salesforce and Stax, and getting them to "live".
- **Compliance** sits inside that flow. Whether compliance is a separate function or an activity that Sales Support carries out themselves is unclear today **(inferred, confirm)**.
- **Tony Lilley** owns the commercial side: BDM management, panel growth, the commercial KPIs.
- **Gemma Bloomer** owns the operational side as Office Manager: she is either running Sales Support directly or close enough to it that she can speak for them. **(inferred, confirm — is Gemma the line manager of Sales Support, or is there someone in between?)**

## Where the handoff happens

The handoff between BDM and Sales Support is currently informal. It is not a system event; it is more likely a Slack message or an email. **(inferred, confirm — how does Sales Support actually find out a new retailer is theirs to onboard? Who tells them, and what do they get told?)**

This is one of the most important things to nail down in the Tony / BDM / Sales Support interviews, because the proposed v1 puts a hard role boundary at "Application → Compliance check" and that boundary only works if the handoff matches it.

## What "Setup in Stax" actually means

From what Barney has described, "Setup in Stax" is a bundle of manual work that happens once a retailer has cleared compliance and signed the contract. It includes:

- Creating the retailer Account in Salesforce (or confirming the SF Account record already exists and is tagged correctly).
- Creating one or more Contact records against that Account.
- Configuring lender routing for the retailer in Stax: which of the panel lenders (Norwich Capital, Zopa, This Bank, Propensio, BNP Paribas, V12, Tandem) the retailer can submit to, in what order, with what waterfall logic.
- Configuring any commercial parameters: commission, retailer-specific product set, branding if relevant.
- Issuing the retailer their login credentials and walking them through how to run a quote.

**(inferred, confirm — exact list of fields and who configures them. Likely this is mostly Sales Support, with some bits maybe done by Nicky or one of the developers if it's anything technical like Stax config.)**

This is the piece v1 of the CRM does not replace. The CRM tracks that this work happened, and pushes Account + Contact into Salesforce when the retailer hits "Setup in Stax", but the actual lender routing and Stax config still happens manually in Salesforce/Stax. The CRM is a pipeline tracker plus a Salesforce-write integration, nothing more in v1.

## Known pain points (Barney's framing)

These are the problems v1 is supposed to solve, as currently understood:

- **Pipeline visibility.** Tony and Gemma cannot see at a glance how many retailers are in flight, what stage each is at, who's stuck, who's gone quiet. The spreadsheet is updated unevenly and Slack scatters the information.
- **Compliance gating.** It is too easy today for a retailer to slip through to "live" without every compliance step having been signed off, because the gate is a human checking a spreadsheet rather than a required field on a stage transition.
- **Handoff drops.** Things fall between BDM and Sales Support: documents promised but never delivered, Sales Support not knowing a new retailer is theirs, BDMs not knowing whether their retailer has actually been set up.
- **Commercial reporting.** Stage-conversion rates, time-in-stage, BDM performance: none of these are easy to pull today because the data is not in one place.

## What we are NOT changing in v1

To keep the scope of the Phase 0 discovery honest:

- **Stax stays the loan origination system.** We are not touching Stax application processing.
- **Salesforce stays the production system once a retailer is live.** The CRM pushes to SF; SF is not migrated.
- **No replacement for the manual Stax/SF configuration work.** v1 records that it happened, it does not automate it.
- **Required-fields-per-stage, not Trello checklists.** v1 enforces stage gating by required fields. A more flexible per-stage checklist is a v2 idea.

## What this doc is for

It exists so the four interviews can verify or correct the picture above. Every "(inferred, confirm)" tag is a question that should get a clean yes/no by the end of the interview round. After the interviews, this doc gets rewritten in place as the confirmed current-state map, and `diff-vs-proposed-v1.md` becomes the action list for v1 design changes.
