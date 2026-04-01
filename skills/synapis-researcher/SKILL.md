# Sinapsis Researcher v1.0

> Deep research skill for multi-source investigation and synthesis.
> Use when thorough analysis is needed on any topic.

---

## When to Use

Trigger on:
- "Research X", "Investigate Y", "Deep dive into Z"
- "Compare A vs B", "What are the best options for..."
- "Pros and cons of...", "How does X work?"
- "Find best practices for...", "State of the art in..."
- Any request requiring multi-source synthesis

---

## Research Protocol

### Phase 1: Scope Definition

Before searching, clarify the research scope:

```
RESEARCH BRIEF

  Topic:     [extracted from user request]
  Type:      [comparison | investigation | survey | analysis | how-to]
  Depth:     [quick (5 min) | standard (15 min) | deep (30+ min)]
  Focus:     [technical | business | strategic | educational]
  Output:    [summary | report | comparison table | recommendation]

  Does this scope look right? [Y] Proceed  [E] Edit scope
```

If the user's request is clear enough, skip scope confirmation and proceed directly.

### Phase 2: Source Gathering

Use available tools in this priority order:

1. **Web Search** -- broad search for recent, authoritative sources
2. **Documentation** -- official docs via Context7 or direct fetch
3. **Code Search** -- GitHub repos for real-world implementations
4. **Local Knowledge** -- instincts and observations from Sinapsis
5. **Cached Research** -- previous research on similar topics

### Phase 3: Source Evaluation

Rate each source on:

| Criterion | Weight | Scale |
|-----------|--------|-------|
| Authority | 30% | Official docs > Blog > Forum > Social |
| Recency | 25% | Last 6 months > 1 year > 2 years > older |
| Depth | 20% | Tutorial > Overview > Mention |
| Relevance | 15% | Direct match > Related > Tangential |
| Consensus | 10% | Multiple sources agree > Single source |

Discard sources scoring below 40% weighted total.

### Phase 4: Synthesis

Combine findings into a coherent analysis:

1. **Identify themes** -- group findings by topic/subtopic
2. **Find consensus** -- what do most sources agree on?
3. **Note conflicts** -- where do sources disagree? Why?
4. **Extract actionable items** -- what can the user do with this?
5. **Rate confidence** -- how confident are we in each finding?

### Phase 5: Output

---

## Output Formats

### Summary (Default)

```
RESEARCH: [Topic]

  KEY FINDINGS
  1. [Finding with confidence level]
  2. [Finding with confidence level]
  3. [Finding with confidence level]

  RECOMMENDATIONS
  - [Actionable recommendation]
  - [Actionable recommendation]

  SOURCES
  1. [Source title] -- [URL] (authority: high, date: 2025-02)
  2. [Source title] -- [URL] (authority: medium, date: 2025-01)

  CONFIDENCE: [overall confidence in findings]
  GAPS: [what we could not determine]
```

### Comparison Table

```
COMPARISON: [Option A] vs [Option B] vs [Option C]

  Criterion        | Option A    | Option B    | Option C
  -----------------+-------------+-------------+------------
  Performance      | Fast        | Medium      | Fastest
  Learning curve   | Low         | High        | Medium
  Community        | Large       | Small       | Growing
  Cost             | Free        | $99/mo      | Freemium
  Best for         | Startups    | Enterprise  | Mid-size

  VERDICT: [Recommendation based on user's context]

  Sources: [numbered list]
```

### Deep Report

For `/deep-dive` or when depth = deep:

```
RESEARCH REPORT: [Topic]
Date: [current date]

  EXECUTIVE SUMMARY
  [2-3 paragraph overview]

  TABLE OF CONTENTS
  1. Background
  2. Current State
  3. Key Players / Options
  4. Analysis
  5. Recommendations
  6. Sources

  [Full sections follow...]
```

---

## Research Strategies by Type

### Technology Comparison
1. Search for "[tech A] vs [tech B] {current year}"
2. Check official documentation for both
3. Look for benchmark data
4. Find migration guides (indicates maturity)
5. Check GitHub stars/activity as community proxy
6. Synthesize with pros/cons table

### Best Practices Investigation
1. Search official documentation first
2. Find "[topic] best practices {current year}"
3. Check for style guides from major companies
4. Look for common pitfalls / anti-patterns
5. Cross-reference with community consensus
6. Synthesize with do/don't list

### "How Does X Work?" Deep Dive
1. Start with official docs / specification
2. Find architectural overviews
3. Look for "under the hood" articles
4. Check for reference implementations
5. Synthesize with layered explanation (simple -> detailed)

### Market / Landscape Survey
1. Search for "[space] landscape {current year}"
2. Identify key players and categories
3. Find pricing/feature comparison data
4. Look for analyst reports or reviews
5. Synthesize with categorized map

---

## Quality Controls

### Bias Detection
- Flag if all sources come from a single author/company
- Note if research only found positive OR negative perspectives
- Warn if sources are primarily marketing material

### Freshness Check
- For fast-moving topics (AI, JS frameworks): prefer sources < 6 months old
- For stable topics (algorithms, protocols): older sources acceptable
- Always note the date of each source

### Confidence Levels
- **High** (0.8-1.0): Multiple authoritative sources agree
- **Medium** (0.5-0.8): Some agreement, some gaps
- **Low** (0.3-0.5): Limited sources, conflicting information
- **Speculative** (< 0.3): Mostly inference, little hard data

---

## Integration Points

- **Sinapsis Learning**: Research findings can generate new instincts
- **Sinapsis Instincts**: Existing instincts provide context for research
- **Skill Router**: May install research-related skills as needed
- **Operator State**: Cross-project research lessons stored here
