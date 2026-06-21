# Chart Info Tooltips — Final Copy

Each chart's ⓘ tooltip contains two sections:
- **Part 1: Data Rules & Interaction** — how the data is calculated + how to interact
- **Part 2: Health Insight** — what the user can learn from this chart

---

## 1. Log Calendar

### Part 1 — Data Rules & Interaction

Each cell represents one day. The color intensity reflects how many bowel records you logged — more records produce a darker shade. Days without any logs remain blank.

**Tip:** Tap any day to open a panel showing all records for that date.

### Part 2 — Health Insight

Tracking your bowel frequency helps you recognize your personal rhythm. Irregular gaps or sudden spikes may signal dietary changes, stress, or other factors worth noting. A consistent pattern (1–3 times daily, or once every 1–2 days) is generally considered healthy.

---

## 2. Overall Status Distribution

### Part 1 — Data Rules & Interaction

Each record is classified into one of five statuses based on your questionnaire answers:

- **Ideal** — smooth result, minimal effort, complete evacuation, well-formed consistency, no discomfort
- **Dry/Hard** — excessive straining, hard or pellet-like consistency, prolonged effort
- **Incomplete/Not Smooth** — residual sensation, blocked feeling, needed positional changes or assistance
- **Soft/Urgent** — loose consistency, strong urgency, difficulty holding
- **Unsuccessful** — attempted but unable to pass stool

Each answer contributes weighted points toward one or more statuses. The status with the highest total score becomes the record's primary classification. When two conflicting statuses (e.g., Dry/Hard and Soft/Urgent) both score highly, the record is excluded to ensure data accuracy.

The chart shows the proportion of each status across the selected 7- or 30-day window.

**Tip:** Tap each segment to see the exact count and percentage for that status.

### Part 2 — Health Insight

This chart reveals your dominant bowel pattern. A high proportion of "Ideal" suggests your digestive system is functioning well. Frequent "Dry/Hard" may indicate insufficient hydration or fiber intake. Repeated "Soft/Urgent" could be linked to dietary irritants or stress. Use this overview to identify patterns worth discussing with your healthcare provider.

---

## 3. Status Trends

### Part 1 — Data Rules & Interaction

Each data point represents a **Bowel Health Score (0–100)** for that day, derived from five weighted dimensions:

| Dimension | Weight | What it measures |
|-----------|--------|-----------------|
| Result | 20% | Whether stool was passed successfully |
| Straining | 15% | Level of effort required |
| Evacuation | 20% | Sense of completeness afterwards |
| Consistency | 20% | Stool form (well-formed vs. hard/loose) |
| Pain & Discomfort | 25% | Presence of pain, urgency, or other symptoms |

Each dimension is scored individually based on your questionnaire answers, then multiplied by its weight to produce a combined daily score. If you have multiple records in one day, the score shown is the average of all valid records.

Higher scores indicate better bowel health for that day.

**Tip:** Tap any data point to expand the full score breakdown and see how each of the five dimensions contributed.

### Part 2 — Health Insight

This trend line helps you spot gradual improvements or declines over time. A rising trend suggests your bowel habits are improving; a declining trend may prompt you to review recent changes in diet, stress, or routine. Consistent scores above 70 generally indicate healthy bowel function.

---

## 4. Bowel Issue Breakdown

### Shared context

Issues identified from your questionnaire are categorized into three dimensions:

- **Physiological** — physical symptoms such as straining, incomplete evacuation, hard consistency, blocked sensation, and related indicators
- **Psychological** — anxiety, tension, and emotional triggers related to bowel movements
- **External/Lifestyle** — environmental discomfort, time pressure, interruptions, dietary triggers, and routine changes

Each dimension is scored using a combination of core indicators (primary symptoms) and companion indicators (supporting signals), with different weights. The three dimensions are then normalized to percentages that sum to 100%.

When multiple records exist on the same day, they are combined using a weighted average — records with stronger physical symptoms carry more weight in the daily total.

---

### 4a. Radar View

#### Part 1 — Data Rules & Interaction

The radar shape shows the **period average** of each dimension's percentage across all valid records in the selected 7- or 30-day window. Each axis represents one dimension (Physiological / Psychological / External). The further the shape extends along an axis, the more dominant that issue category is.

**Tip:** Tap any axis or grid area to view the exact percentage and number of contributing records for that dimension.

#### Part 2 — Health Insight

This chart shows which category of factors affects your bowel health most at a glance. A shape heavily skewed toward "Physiological" may suggest a need for dietary adjustments or medical consultation. Skew toward "Psychological" hints at stress-related bowel patterns. "External" dominance suggests your environment or daily routine could be improved. A smaller, balanced shape is the ideal goal.

---

### 4b. Stacked Bar View

#### Part 1 — Data Rules & Interaction

Each bar represents one day, divided into three colored segments showing the percentage split among Physiological, Psychological, and External dimensions. Taller overall presence on a day simply means data is available; the segment proportions reveal which category dominated.

When multiple records exist on the same day, they are combined using a weighted average that gives more influence to records with stronger physical core symptoms.

Days with no valid questionnaire data show no bar.

**Tip:** Tap any bar to see individual record breakdowns for that day, showing how each record contributed to the daily totals.

#### Part 2 — Health Insight

This view reveals day-to-day variation in your issue drivers. Look for patterns — for example, does "Psychological" consistently spike on work days? Does "External" rise when you travel? Correlating bar patterns with your daily routine may reveal specific triggers you can address.

---

### 4c. Line View

#### Part 1 — Data Rules & Interaction

Three lines track the daily percentage of each dimension (Physiological / Psychological / External) over the selected 7- or 30-day window. The three percentages always sum to 100% for each day. Days without valid questionnaire data are skipped — lines connect directly between days that have data.

**Tip:** Tap any data point to see the exact dimension percentages and the number of records for that day.

#### Part 2 — Health Insight

Use this view to track how your issue composition shifts over time. A declining Physiological line after dietary changes validates your efforts. A rising Psychological line during busy periods confirms that stress impacts your bowel habits. Identifying these trends empowers you to make targeted lifestyle adjustments and track their effectiveness.

---

## Notes for Implementation

- All charts support 7-day and 30-day time windows; the tooltip text uses "selected 7- or 30-day window" to remain generic.
- When fewer than 3 days have valid data in the selected window, a "Limited data" notice should appear alongside the chart (already implemented in code).
- Tooltip UI design is out of scope for this document — this covers text content only.
