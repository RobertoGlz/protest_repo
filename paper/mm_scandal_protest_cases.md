# Protests within five days of an apex-corruption scandal: three case studies

This note documents three concrete protests drawn from the **Mass Mobilization (MM)
project** dataset (`Data/raw/Protests/MM/MMraw.csv`) that occurred **on the disclosure
date of one of our corruption scandals, or within five days of it**. All three scandals
are *apex* events (a sitting **president**), which is the partition that drives the
paper's headline result.

**How the cases were selected.** For every scandal in the analysis panel
(`protests_scandals_30days_v3.dta`, disclosure date = the day of the event window) I
joined the raw MM protest events on country and kept every MM protest whose start date
fell in the closed interval `[scandal_date, scandal_date + 5]`. That produced 33
protest–scandal pairs; the three below were chosen for being apex scandals with the
richest MM narrative and the clearest documentary trail.

### How to read the source flags

- **`[MM]`** — the statement comes **directly from the MM dataset** (its `notes`,
  `sources`, `participants`, `location`, `protesterviolence`, `protesterdemand*`, or
  `stateresponse*` fields). MM's own `notes`/`sources` are themselves compiled from
  contemporaneous newswire and newspaper reports, which I reproduce or paraphrase.
- **`[WEB]`** — context I added from an **internet search**, with the source named
  inline. This is *not* in the MM dataset; it is included to date the scandal precisely,
  confirm participant counts, or record what happened afterward.
- Interpretive cautions (e.g., a co-occurring shock) are called out explicitly so the
  match is not oversold.

---

## Case 1 — Brazil: the JBS/"Joesley" tape and President Michel Temer

| | |
|---|---|
| **Scandal (our data)** | id `104`, Brazil, apex (**president**). Disclosure date **17 May 2017**. |
| **MM protest** | id `1402017007`, start **18 May 2017** (**+1 day**). |
| **Violent?** | **Yes** — `protesterviolence = 1`. `[MM]` |
| **Where / who / how many** | `location = national`; `participants_category = >10000`; `participants = 35000`; `protesteridentity = protesters`. `[MM]` |
| **Demand / state response** | `protesterdemand1 = political behavior, process`; `stateresponse1 = crowd dispersal`, `stateresponse2 = arrests`. `[MM]` |

**The scandal.** On **17 May 2017** Brazilian media published a covert recording in which
Joesley Batista, co-owner of the meat-packing giant JBS, appears to capture President
Michel Temer endorsing hush-money payments to the jailed former House speaker Eduardo
Cunha. `[MM]` (MM's `sources` cite *The Times* of London, 19 May 2017: *"brazil president
taped agreeing 120m in bribes"*.) Traders nicknamed 17 May **"Joesley Day"**; the São
Paulo stock market fell nearly 9% the next day, its worst session in nearly a decade.
`[WEB — Latin America Daily Briefing / BBC, 18 May 2017]` The recording was made as part
of the Batista brothers' own plea bargain. `[WEB — The Bureau of Investigative
Journalism]`

**The protest (MM narrative, verbatim substance).** MM records a violent,
national-scale mobilization the day after disclosure: *"thousands of Brazilians took
part in demonstrations … calling for President Temer to resign after a newspaper
reported that prosecutors have a tape of him agreeing to the payment of hush money … a
protest that was supposed to be peaceful deteriorated into violence, vandalism … they
started throwing percussion grenades, tear gas and rubber bullets … some protesters hid
behind shields, and others threw percussion grenades back at the police … in Rio de
Janeiro, police officers … came under attack by demonstrators wielding slingshots."*
`[MM]` MM also records that the president **deployed federal troops** to the capital to
restore order. `[MM]` (MM `sources`: *New York Times*, 25 May 2017, *"Brazil's president
deploys armed forces to quell protesters calling for his removal."*)

**Interpretive note — the date field vs. the narrative.** MM stamps this record **18 May
2017** (one day after the scandal) and gives 35,000 participants, but the vivid clash it
narrates — troops on the Esplanade of Ministries, a fire inside the Ministry of
Agriculture, rubber bullets and tear gas — is the **24 May 2017** escalation, when an
estimated 35,000 marched in Brasília and Temer briefly invoked a *Guarantee of Law and
Order* (GLO) decree deploying ~1,500 soldiers before revoking it under criticism.
`[WEB — BBC, "Brazil protests: Temer revokes decree deploying troops"; euronews, 25 May
2017]` In other words, MM anchors the event to the first post-disclosure protest day but
folds the week-long wave's peak violence into the same record. Either way, the protest is
**squarely and explicitly about the corruption disclosure** — the cleanest apex →
violent-protest case in the five-day window.

---

## Case 2 — Mexico: the "Casa Blanca" of President Enrique Peña Nieto

| | |
|---|---|
| **Scandal (our data)** | id `64`, Mexico, apex (**president**). Disclosure date **9 Nov 2014**. |
| **MM protests** | a cluster of four: ids `702014011`–`702014014`, starting **9, 10, 11 and 13 Nov 2014** (**+0 to +4 days**). |
| **Violent?** | **Yes** — all four `protesterviolence = 1`. `[MM]` |

**The scandal.** On **9 November 2014** the investigative team of journalist Carmen
Aristegui published *"La Casa Blanca de Enrique Peña Nieto,"* revealing a ~86-million-peso
mansion in Lomas de Chapultepec linked to the president and a favored government
contractor (Grupo Higa). `[MM]` The report was released jointly with Proceso, La Jornada,
and international outlets. `[WEB — Infobae; El Universal, retrospectives on the sexenio]`

**The protests (MM narrative).** MM logs four violent protests in the window:

- **9 Nov (day 0), Mexico City** (`702014011`, 5,000–10,000): *"protesters tried to storm
  Mexico City's National Palace … a small group broke away and tried to smash down the
  doors … They threw petrol bombs, chanted slogans denouncing President Peña Nieto and
  spray-painted 'we want them back alive' on the walls before police drove them back."*
  `stateresponse1 = crowd dispersal`. `[MM]`
- **10 Nov (day 1), Acapulco** (`702014012`): *"thousands of protesters blocked access to
  the airport … Twenty riot police were injured in the clashes."* `[MM]`
- **11 Nov (day 2), Guerrero** (`702014013`, teachers and students): set fire to the state
  headquarters of the president's party (PRI) and *"at one point detained the state
  security chief but later released him."* `[MM]`
- **13 Nov (day 4), Guerrero** (`702014014`, teachers): *"mobs set fire to the party
  headquarters … crowds attacked the congress building … and set the state headquarters
  … ablaze."* `[MM]`

The recorded demands are `police brutality` and `political behavior, process`. `[MM]`

**Interpretive note — a co-occurring shock (important).** The MM `notes` make explicit
that the **proximate trigger** of this violence was **not** the Casa Blanca corruption
report but the **Ayotzinapa case**: the 43 teaching students abducted in Iguala,
Guerrero, on 26 September 2014, whose apparent murder was announced by the Attorney
General on 7 November 2014. `[MM]` The National Palace door was in fact burned during an
Ayotzinapa march. `[WEB — Justice in Mexico; contemporaneous reporting]` The Casa Blanca
scandal (9 Nov) and the Ayotzinapa announcement (7 Nov) **landed the same week**, and the
two grievances fused in the streets. This case is therefore a genuine within-window match
in the data *and* a clean illustration of why the design needs the apex-vs-non-apex
contrast and rich fixed effects: raw proximity to a scandal date can coincide with a
separate, overlapping shock. I flag it rather than present it as pure corruption-driven
violence.

---

## Case 3 — Guatemala: "La Línea" and President Otto Pérez Molina

| | |
|---|---|
| **Scandal (our data)** | id `NEW8`, Guatemala, apex (**president**). Disclosure date **24 Aug 2015**. |
| **MM protest** | id `902015017`, start **27 Aug 2015** (**+3 days**). |
| **Violent?** | **No** — `protesterviolence = 0` (peaceful, but very large). `[MM]` |
| **Where / who / how many** | `location = Guatemala City`; `participants_category = >10000`; `participants = 10000s`; `protesteridentity = protesters`. `[MM]` |
| **Demand / state response** | `protesterdemand1 = removal of politician`, `protesterdemand2 = political behavior, process`; `stateresponse1 = ignore`. `[MM]` |

**The scandal.** The **La Línea** case — a customs-fraud ring that discounted import
duties in exchange for kickbacks — was first exposed by the UN-backed CICIG and the Public
Ministry in **April 2015**. `[WEB — Wikipedia, "2015 Guatemalan protests"; InSight Crime]`
Our disclosure date, **24 August 2015**, marks the escalation to the top: MM's scandal
description is *"Graban al presidente Otto involucrado directamente en el caso La Línea"*
(recordings implicating President Pérez Molina directly), sourced to an emisorasunidas
report archived 24 Aug 2015. `[our scandal data]` That same day CICIG and prosecutors
filed charges naming him as the ring's leader, backed by ~89,000 wiretaps. `[WEB —
Latin America Daily Briefing, 24 Aug 2015]`

**The protest (MM narrative).** Three days later MM records a peaceful mass mobilization:
*"tens of thousands of protesters in Guatemala City call on Pres. Otto Perez to step down
after a series of corruption scandals that have implicated him and other members of his
administration, including Vice Pres. Roxanna Baldetti, now under arrest."* `[MM]` (MM
`sources`: *Washington Post*, 28 Aug 2015, *"Guatemalan leader under pressure to
resign"*; *Wall Street Journal*, 28 Aug 2015.) The demand coded is literally *removal of
the politician*, and the state did not repress it (`stateresponse = ignore`) — consistent
with the broadly non-violent, cross-class character of Guatemala's 2015 movement.

**What happened next.** `[WEB]` An arrest warrant issued around 25 August 2015; Congress
voted **unanimously on 1 September 2015** to strip the president's immunity; **Pérez
Molina resigned on 3 September 2015** and was jailed pending trial. `[WEB — BBC, "Guatemala's
President Otto Perez Molina resigns"; Latin America Daily Briefing, 3 Sept 2015]` This is
the paper's mechanism in its starkest form — an apex-corruption disclosure followed within
days by a mass mobilization demanding, and obtaining, the president's fall — and it shows
that the apex effect operates through *large* protests that need not be violent.

---

## Summary

| Case | Scandal date | Protest date | Lag | Violent? | Link to the scandal |
|---|---|---|---|---|---|
| Brazil — Temer / JBS tape | 17 May 2017 | 18 May 2017 (wave peaks 24 May) | +1 (–7) day | **Yes** `[MM]` | Explicit: "resign after … a tape" `[MM]` |
| Mexico — Casa Blanca / Peña Nieto | 9 Nov 2014 | 9–13 Nov 2014 | +0 to +4 days | **Yes** `[MM]` | Window match, but proximately driven by Ayotzinapa `[MM]` — flagged |
| Guatemala — La Línea / Pérez Molina | 24 Aug 2015 | 27 Aug 2015 | +3 days | No (mass peaceful) `[MM]` | Explicit: "call on … Otto Perez to step down" `[MM]` |

**Bottom line.** Two of the three (Brazil, Guatemala) are textbook apex-corruption →
protest events in which the MM narrative names the scandal as the grievance; Brazil turned
violent within a week and drew a troop deployment, while Guatemala's remained peaceful but
was large enough to topple the president. The Mexican case is a true within-window match
whose street violence was proximately fueled by the overlapping Ayotzinapa shock — a
useful reminder, flagged honestly, that date-proximity alone is not identification, which
is exactly what the paper's apex/non-apex contrast and fixed-effects design are there to
handle.

*All protest-level facts flagged `[MM]` are from `Data/raw/Protests/MM/MMraw.csv` (Mass
Mobilization project, Clark & Regan). Facts flagged `[WEB]` are from the internet sources
named inline and are not part of the MM dataset.*
