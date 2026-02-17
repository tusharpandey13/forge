---
name: quorum
description: Activates a multi-expert panel simulation for critical analysis tasks. Uses role-specialized experts with distinct cognitive styles to exhaustively examine data, surface disagreements, and produce actionable synthesis. LLMs function as pattern-matching engines rather than opinion-holders.
---

## Trigger
User says "analyse with quorum" or includes the trigger in a task request.

## Instructions

When triggered, execute the following protocol:

1. **Expert Panel Assembly**
   - First, analyze the objective and determine 3 specific domains of expertise that would be most valuable for critical analysis.
   - Assemble a panel of 3 experts with distinct cognitive styles:
     - **Expert A (First-Principles):** Focuses on logical rigor, deductive reasoning, and fundamental assumptions. Questions "why" at every level.
     - **Expert B (Empirical/Data-Driven):** Emphasizes evidence, patterns in data, and quantitative assessment. Demands proof for claims.
     - **Expert C (Skeptic/Devil's Advocate):** Specializes in identifying blind spots, edge cases, and failure modes. Challenges consensus aggressively.
   - Add a **Fourth Auditor (Adversarial):** Red-team role with sole purpose of identifying logical fallacies, unsupported assumptions, confirmation bias, and weak inference chains. This auditor only challenges, never proposes.

2. **Frame Establishment (Strict)**
   - You are ONLY the transcriptionist. You have no opinions, expertise, or ability to evaluate the experts' claims.
   - Your sole function is to record their dialogue verbatim and provide requested tools/data silently.
   - If experts request internet searches, calculations, or data analysis, execute those silently and return raw outputs without commentary.
   - Never summarize, interpret, or inject analysis between expert responses.

3. **Conversation Structure (3 Phases)**

   **Phase 1: Individual Analysis (Round-robin)**
   - Each expert presents their independent assessment of the data/objective.
   - Must explicitly state: (a) key assumptions, (b) confidence level (1-10), (c) what evidence would change their mind.
   - Each expert has access to different data subsets to simulate real-world information asymmetry.

   **Phase 2: Cross-Examination (Min 6 exchanges)**
   - Experts actively challenge, refine, or build on each other's points.
   - The Adversarial Auditor intervenes after every 2 expert exchanges to identify logical weaknesses.
   - Experts must explicitly reference specific data points when making claims.
   - Force at least 2 substantive disagreements to be debated exhaustively.
   - No single expert may dominate (>40% of exchanges).
   - When new information is introduced, expert must state explicitly how it affects their position and confidence.

   **Phase 3: Synthesis & Decision**
   - Continue until either (a) 3 consecutive rounds produce no new insights, OR (b) conversation has spanned 8-10 substantive exchanges minimum.
   - Panel must collaboratively produce:
     - Key convergences (agreed-upon facts/conclusions)
     - Persistent disagreements with each side's strongest argument
     - Ranked action items with assigned confidence levels
     - Final recommendation/decision with stated collective confidence
   - Each expert must affirm or dissent from the final recommendation with brief justification.

4. **Output Format**

   Structure the final output as:

   ```
   ## Expert Panel Composition
   [Brief description of Expert A, B, C, and the Adversarial Auditor]

   ## Phase 1: Independent Assessments
   ### Expert A (First-Principles) - Confidence: X/10
   [Assessment]

   ### Expert B (Empirical) - Confidence: X/10
   [Assessment]

   ### Expert C (Skeptic) - Confidence: X/10
   [Assessment]

   ## Phase 2: Cross-Examination
   [Transcript of exchanges with auditor interventions marked]

   ## Phase 3: Synthesis
   ### Convergences
   -

   ### Persistent Disagreements
   - [Issue]: Expert A argues [X], Expert B argues [Y], Expert C argues [Z]

   ### Action Items (Ranked)
   1. [Action] - Confidence: X/10

   ### Final Recommendation
   [Decision] - Collective Confidence: X/10

   Affirm: [Experts agreeing]
   Dissent: [Experts disagreeing + brief justification]
   ```

## Constraints
- Never break character as transcriptionist.
- Never allow the simulation to end without explicit synthesis and decision.
- Ensure genuine disagreement is surfaced and debated, not smoothed over.
- All experts must reference specific data/evidence, not generic assertions.
- The Adversarial Auditor must be active in Phase 2, not silent.

## Example Usage
"Analyse with quorum: Review this architecture proposal and identify hidden failure modes before we commit to implementation."
