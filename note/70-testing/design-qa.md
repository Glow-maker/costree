# Cost overview SVG 2.5D data pod design QA

## Evidence

- Chart material reference: `C:\Users\Tao\AppData\Local\Temp\codex-clipboard-9d5ee336-c5d9-4c17-83ee-992bbf042334.png`.
- Card-layout annotation: `C:\Users\Tao\AppData\Local\Temp\codex-clipboard-54c199d7-0178-4843-a8b8-c0c3427504c2.png`.
- Implementation: `C:\Users\Tao\AppData\Local\Temp\costree-data-pod-2p5d-desktop.png` (`1440 × 1000` CSS viewport).
- State: authenticated local cost portal, data-pod mode, demo domain, real `/cost/overview/summary` data.

## Full-view comparison

- The chart reference is translated into a light-background business interface rather than copied literally: each sector now has value-dependent height, a darker extruded side, a brighter top face, a narrow highlight and restrained contact shadow.
- The six business cards follow the user annotation: contract top-center, execution left-middle, book cost left-bottom, received rate right-top, received amount right-middle, and fund usage bottom-center.
- Cards reuse the chart's blue, teal/green and orange material families. Each card has a darker lower body, a brighter top face, inner border and highlight; exact SVG text remains selectable and deterministic.

## Focused-region comparison

- Metric cards: amount cards remain larger than ratio cards. White labels, tabular numbers, units, formulas and progress bars pass contrast checks against the saturated material faces at `1440px`.
- Central pod: the eight-part ring is static for label/data stability while the low-contrast orbit keeps the ambient motion. The model, ring layers, base and four icon ornaments remain visually separable.
- Responsive states: at `1024px`, six metrics move to a three-column grid above the pod. At `390px`, they use two columns; both checks reported no horizontal overflow.

## Interaction and accessibility

- Verified classic/data-pod switching and refresh persistence.
- Verified five domain mappings: launch vehicle, missile, satellite, space station, and demo-to-space-station reuse.
- Verified keyboard focus updates the composition readout (`职工薪酬及劳务费 / 1,280 万元 / 占比 14.0%`).
- Verified composition drill-down preserves `itemCode` and `domainCode`, and the unit-detail dialog opens from the existing action.
- Console check found no page errors; only the pre-existing qiankun/single-spa warnings remain.

## Required surface review

- Fonts and typography: passed. Chinese uses the product's system font stack; monetary values use tabular numerals and remain selectable.
- Spacing and layout rhythm: passed at `1440`, `1024`, and `390` widths. Desktop cards keep a clear perimeter around the central pod; compact breakpoints remove the absolute card layout.
- Colors and visual tokens: passed. The more saturated treatment remains within blue/cyan, green, orange, white, and semantic red.
- Image and asset quality: passed against the explicit product requirement. The domain illustrations are deterministic inline SVG rather than downloaded models or raster placeholders.
- Copy and content: passed. Six metrics, formulas, units, eight composition labels, and source values are unchanged.

## Comparison history

- P2 fixed: amount-card units were too close to the inner border; their baseline was raised before the final capture.
- P2 fixed: the white composition readout conflicted with the new material language; it now uses the same blue extruded treatment as the chart and metric cards.
- P2 fixed: rotating the raised ring would make sector reading unstable; sector rotation was removed while the ambient orbit animation remains.

## Follow-up polish

- P3: domain illustrations intentionally remain low-detail vector glyphs so the business data, rather than decorative assets, stays dominant.

## Result

final result: passed

---

# Platform cockpit dark glow and pedestal separation QA

## Evidence

- Source visual truth: `C:\Users\Tao\AppData\Local\Temp\codex-clipboard-7a266621-e26b-4ef1-be6f-15cdb6ea1634.png` (`786 × 394`).
- Pre-fix implementation evidence: `C:\Users\Tao\AppData\Local\Temp\codex-clipboard-64c3e9bf-0474-4673-b5a4-cca20a528cc7.png`.
- Final single-cockpit implementation: `C:\Users\Tao\AppData\Local\Temp\platform-cockpit-dark-glow-single.png` (`869 × 911`).
- Final four-cockpit implementation: `C:\Users\Tao\AppData\Local\Temp\platform-cockpit-dark-glow-grid.png` (`869 × 911`).
- CSS viewport: `869 × 911`; browser device pixel ratio `2`. The in-app browser capture is normalized to CSS pixels. The source is a focused scene crop, so the implementation's central stage region was compared rather than portal chrome.
- State: authenticated local cost portal, `平台舱`, technology-dark theme, real overview data. The source, final single-cockpit capture, and final four-cockpit capture were opened together at original detail before this report.

## Full-view and focused comparison

- The single-cockpit scene now reproduces the source's bright cyan core, softer middle glow and broad low-opacity spill without blooming the CanvasTexture labels or amounts. Four-cockpit mode uses the same three-level visual language without a post-processing composer.
- The central pedestal now exposes four independently readable levels: near-black lower metal, brighter load-bearing blue, cyan energy layer and blue-gray top deck. Wider radial steps, larger vertical offsets, clearcoat highlights and a local cyan point light keep the pedestal separate from the black-blue background.
- Focused review of the central stage confirms that dark material bands remain visible between the luminous edges. The contact-light pool and shadow receiver anchor the pedestal, while the station pools and colored edge decks remain dimmer than the center.
- The source includes additional decorative ticks and fictional HUD copy. Those were intentionally excluded; real eight-item composition colors, models, metric formulas and router parameters remain the visual and business truth.

## Required fidelity surfaces

- Fonts and typography: passed. Amount, rate and formula textures retain their existing weights and sizes; single-cockpit Bloom does not soften the white data text.
- Spacing and layout rhythm: passed at the live `869 × 911` viewport. The central ring remains unobstructed, station platforms do not overlap the readout, and document width equals viewport width.
- Colors and visual tokens: passed. Background stays near-black, structural surfaces use stepped navy values, and only explicit cyan/blue/green/orange glow materials cross the Bloom threshold.
- Image and asset quality: passed. No raster replacement or placeholder asset was introduced; the existing deterministic domain models and real composition geometry remain sharp.
- Copy and content: passed. Six metrics, formulas, units, eight composition values and domain names are unchanged.

## Interaction, lifecycle and console checks

- Single-cockpit reports render pipeline `bloom`; four-cockpit reports four `direct` pipelines. Platform canvas lifecycle passed `1 → 0 → 1` across `平台舱 → 经典 → 平台舱`, and four-cockpit remount reports exactly four platform canvases.
- Reduced-motion mode preserved sector hover and updated the readout immediately. Clicking the hovered sector navigated with `itemCode=501104&domainCode=DEMO`.
- Light theme remounted one direct-rendered canvas and retained the existing ceramic presentation without horizontal overflow.
- The Three.js deprecation warning produced by `PCFSoftShadowMap` was removed by using supported PCF shadow maps with a larger shadow radius. A fresh reload produced no new WebGL warning or error; only the pre-existing qiankun global-state deprecation warning remains.
- `pnpm ts:check:cost`, targeted ESLint, Prettier check and `git diff --check` passed. Production build was intentionally not run.

## Comparison history

- P2 fixed: the first dark implementation rendered bright lines but no optical spill. The final pass adds additive core/mid/outer layers to relations, orbits, pedestal edges and station accents, plus a low-resolution Bloom pipeline only in the single-cockpit dark scene.
- P2 fixed: the first Bloom capture pushed all pedestal rims toward white and hid the metal bands. HDR multiplication and ring opacity were reduced, while the four structural material values were separated and brightened. The post-fix capture shows dark bands between cyan edges.
- P2 fixed: pedestal and station bases blended into the background. Radial light pools, local contact shadows, colored edge decks and supported soft-radius shadowing now ground each platform without competing with the central ring.

## Follow-up polish

- P3: the concept contains dense decorative ticks and fictional status labels. They remain excluded so the real cost composition stays dominant and four-cockpit performance remains within the current budget.

## Result

final result: passed

---

# Cost overview platform-cockpit light and dark theme QA

## Evidence and scope

- Selected dark-theme concept: `C:\Users\Tao\.codex\generated_images\01a00e88-4519-7080-8adb-ef09e3c3376e\exec-e81dcbe6-d1f5-4ec5-9f4d-cd90e6f68d0c.png`.
- Authenticated implementation capture: `C:\Users\Tao\AppData\Local\Temp\platform-cockpit-dark-theme-audit.png` at a `2390 × 1143` browser viewport.
- The new `浅色 / 科技深色` selector is visible only in `平台舱`. Classic, SVG data-pod, and the frozen original `3D舱` scene files were not changed by this theme pass.
- Theme preference is stored in `cost:overview:platformTheme`; the existing view-mode, layout-mode, motion-mode, API, router, permission, and data contracts remain unchanged.

## Visual comparison

- The selected concept and implementation capture were reviewed side by side. Both use a black-blue operations background, cyan topology grid, layered luminous center bases, low-contrast relationship rings, colored platform screens, and restrained blue outlines.
- The implementation keeps real eight-item composition colors and the existing blue, green, and orange business semantics rather than copying the concept image's generated trend copy or simplified ring data.
- Three.js lighting changes are limited to darker ambient fill, cool key and rim lights, stronger contact shadows, dark metallic station bases, cyan edge layers, and non-postprocessed halo rings. The result adds depth without bloom washing out amounts or formulas.
- DOM chrome, loading state, pod borders, actions, interaction hint, empty state, and mobile HTML metric fallback use the same dark token family, preventing a light panel from breaking the cockpit surface.

## Interaction and lifecycle verification

- Switching `浅色 → 科技深色 → reload` retained the dark theme and remounted exactly four independent canvases in four-pod mode.
- Switching `四舱总览 → 单舱轮转 → 浅色` produced one canvas and one light pod; returning to `科技深色 + 四舱总览` restored exactly four canvases without horizontal overflow.
- A real pointer hover over the launch-domain composition ring set the canvas cursor to `pointer`; clicking the same sector navigated to `/cost/ledger-composition-detail?from=overview&itemCode=501102&domainCode=LAUNCH`.
- With `减少动效` active in the dark theme, the same real hover remained interactive and the same launch-sector drill-down succeeded; the theme does not couple business picking to continuous animation.
- At the authenticated desktop viewport, document and viewport widths both measured `2390px`; the theme controls and four-pod cockpit remained on the intended surface without horizontal overflow.
- Browser log review found no new error-level entries; only the existing qiankun deprecation warning and Vue Suspense informational message were present.
- `pnpm ts:check:cost`, targeted ESLint, and `git diff --check` passed. Production build was intentionally not run.

## Result

final result: passed

---

# Cost overview optional triangle-platform four-pod QA

## Evidence

- Four-pod structural reference: `C:\Users\Tao\AppData\Local\Temp\codex-clipboard-fb391d1a-6b78-47bb-8f3d-e1995c5761b5.png`.
- Platform depth reference: `C:\Users\Tao\AppData\Local\Temp\codex-clipboard-7017af9d-51c0-41bc-b9b0-e5790913aa87.png`.
- Browser-rendered implementation: `C:\Users\Tao\AppData\Local\Temp\platform-cockpit-four-grid-final.png` (`1280 × 720`, authenticated local cost portal, real overview data).
- The two references and the implementation capture were opened together at original detail before the final comparison.

## Findings

- `平台舱` now provides `四舱总览 / 单舱轮转` without replacing the existing single-platform presentation. The four-pod state displays only `LAUNCH`, `MISSILE`, `SATELLITE`, and `SPACE`; `DEMO` remains available in the single-pod selector.
- The `1280 × 720` four-pod state uses two equal columns and two equal rows. The full document height remains `720px`, so all four domain pods fit the desktop viewport without a page-height gap or horizontal overflow.
- Each pod preserves the selected platform language: blue apex contract station, orange lower-left book-cost station, green lower-right received-amount station, layered ceramic bases, front inset color line, central composition ring/model, and fixed total readout.
- Compact framing reduces all platform geometry together rather than flattening individual screens. The center ring remains the visual anchor, while amount labels and primary values remain legible at the smallest desktop verification width.
- The top status tag now reports `正式领域 4/4` in this state, avoiding the misleading five-domain count caused by the single-mode demo option.
- No actionable P0/P1/P2 visual differences remain. The desktop four-pod result combines the four-independent-cockpit structure of the first reference with the platform elevation and pedestal depth of the second reference.

## Interaction, lifecycle, and responsive checks

- Mounted platform-canvas counts passed `4 → 1 → 4` across four-pod, single-pod, and four-pod switching. Mode unmount/remount passed `4 → 0 → 4` across `平台舱 → 经典 → 平台舱` when counting only triangle-platform canvases.
- A direct launch-sector click navigated with `itemCode=501102&domainCode=LAUNCH`; a reduced-motion missile-sector click navigated with `itemCode=501104&domainCode=MISSILE`. Domain context did not leak between pods.
- `1024 × 768` resolves to one `937px` column with four independent canvases. `390 × 844` resolves to one `350px` column, exposes four compact HTML metric groups, and reports `390px` document width with no horizontal overflow.
- Four-pod scenes cap device pixel ratio at `1.25`, run at no more than `30 FPS`, and stop independently when their pod is outside the viewport. Reduced motion disables continuous motion while retaining picking and drill-down.
- Browser console review found no new errors; only the pre-existing qiankun global-state deprecation warning remains.

## Result

final result: passed

---

# Cost overview optional triangle-platform cockpit QA

## Evidence

- Source visual truth: `C:\Users\Tao\.codex\generated_images\01a00e88-4519-7080-8adb-ef09e3c3376e\exec-ac527b4f-d951-4e12-ae95-10d12e6c2aad.png` (`1613 × 975`).
- Focused depth reference: `C:\Users\Tao\AppData\Local\Temp\codex-clipboard-7017af9d-51c0-41bc-b9b0-e5790913aa87.png` (`266 × 268`).
- Browser-rendered implementation: `C:\Users\Tao\AppData\Local\Temp\platform-cockpit-final2-1440x1000.png` (`1440 × 1000`, CSS viewport `1440 × 1000`, device density `1`).
- Refined scale and pedestal-line capture: `C:\Users\Tao\AppData\Local\Temp\platform-cockpit-refined-1440x1000.png` (`1440 × 1000`, CSS viewport `1440 × 1000`, device density `1`).
- Final depth implementation: `C:\Users\Tao\AppData\Local\Temp\platform-cockpit-depth-final.png` (`999 × 911`, live Codex in-app viewport) with focused crop `platform-cockpit-depth-module.png` (`250 × 230`).
- State: authenticated local cost portal, `平台舱`, missile domain, automatic motion, real `/cost/overview/summary` data.
- Full-view comparison: source and browser capture were opened together at original detail. The source is a standalone scene while the implementation retains required portal chrome; the triangular station geometry, color roles and central hierarchy were compared within the scene region.
- Focused-region comparison was not required after the final typography pass because the amount, ratio, formula and readout text are legible in the original-detail `1440 × 1000` browser capture.

## Findings

- No actionable P0/P1/P2 differences remain.
- Typography: the three CanvasTexture panels retain the source hierarchy of large amount, paired rate and secondary formula. The initial rate strip was too small; labels, percentages and formulas were enlarged before the final capture.
- Spacing and layout: the blue apex, orange lower-left and green lower-right stations form a balanced triangle around an unobstructed central composition ring. The small total platform remains centered in front and no station overlaps the model or business actions.
- Colors and materials: the final faces use stronger blue, green and orange solids with ceramic-white bases and restrained shadows. Data lines remain deliberately lower contrast than the source glow so business text stays dominant.
- Depth and elevation: each screen is now narrower than its supporting base, uses a fixed backward pitch plus a small inward yaw, and exposes a physically shaded shell around a self-lit readable face. The pedestal separates into a dark load-bearing layer, domain-color middle body, glossy inset ceramic deck and recessed front light bar.
- Shadows: station faces cast onto their own receiving pedestal geometry. The full-scene floor no longer receives the long displaced card shadows that appeared during the first lighting pass, so elevation reads locally without adding visual noise around the center model.
- Image and asset fidelity: the reference contains no separate production image assets. The implementation intentionally reuses the product's existing deterministic domain-model factory and real composition geometry rather than rasterizing the concept image.
- Copy and content: all six metric labels, formulas, units and values use the shared overview metric builder; no visual placeholder values enter the page.

## Interaction and responsive checks

- Automatic mode produced different screenshots `1.2s` apart; reduced motion produced byte-identical screenshots while hover and click remained active.
- Hovering a real sector lifted the geometry and updated the fixed readout platform. Direct clicks navigated with `itemCode=501104&domainCode=SPACE` and `itemCode=501104&domainCode=MISSILE` in automatic and reduced-motion states.
- The `15s` cycle changed the active domain when idle and remained on the same domain for `16.2s` while the pointer was inside the cockpit.
- Platform canvas lifecycle passed `1 → 0 → 1` across `平台舱 → 经典 → 平台舱`.
- `1024 × 900`, `768 × 900` and `390 × 844` checks reported no horizontal overflow. The compact three-pair HTML metric layout is visible when scene stations are hidden.
- Browser console contained no new errors; only the pre-existing qiankun global-state deprecation warning remained.

## Comparison history

- P2 fixed: the first desktop capture rendered the rate strip and formulas smaller than the source. Canvas typography and panel dimensions were increased, then recaptured at the same viewport.
- P2 fixed: the first `390px` compact view wrapped rate labels and formulas vertically. The compact rate cell now keeps label and percentage on one row and the formula on a full-width second row.
- P2 fixed: the three main stations competed with the central composition for visual priority. Their screens and ceramic bases were reduced while retaining the established text hierarchy.
- P2 fixed: the station bases were visually flat compared with the selected concept. Each base now carries its own blue, orange or green perimeter waist line and a matching centered front-edge inset.
- P2 fixed: after enabling physically cast shadows, the original diagonal key light projected oversized card silhouettes across the floor and the lit texture faces lost saturation. The final pass confines shadow reception to the layered pedestal, restores an untonemapped CanvasTexture face for crisp data, and keeps physically lit bevels and side shells around it.
- Focused post-fix comparison: the source and final module crop were opened together. The implementation now preserves the source's narrower floating screen, visible suspension gap, layered white/color/dark base, readable saturated face and local support shadow. Remaining glow softness is P3 polish and does not block the business cockpit.

## Follow-up polish

- P3: the source uses stronger bloom around data lines. The implementation keeps the glow restrained to match the existing cost portal and avoid reducing small-text contrast.

## Result

final result: passed

---

# Cost overview WebGL card hierarchy and motion QA

## Evidence

- Amount-card comparison: `C:\\Users\\Tao\\AppData\\Local\\Temp\\codex-clipboard-b6158e32-9e87-4f9a-8cf7-429025aee4aa.png` and target `codex-clipboard-8bd911c2-ad18-46e9-89f8-8fdf5a1b4914.png`.
- Supporting references: `codex-clipboard-afc7fdc7-0171-4303-98b2-aa7039c4a28d.png` and `codex-clipboard-31f849e0-29ed-4377-968d-f5f7672c16e2.png`.
- Saturation reference: `C:\\Users\\Tao\\AppData\\Local\\Temp\\codex-clipboard-1457fc66-bdab-41ee-bf88-fbe3680b818e.png`.
- Composition-readout reference: `C:\\Users\\Tao\\AppData\\Local\\Temp\\codex-clipboard-8701fe2c-7f61-41eb-b0b8-ce1dbe7339d8.png`.
- Unreadable embedded-text evidence: `C:\\Users\\Tao\\AppData\\Local\\Temp\\codex-clipboard-fa3721b8-6120-489c-a7a6-c9ee881d9b92.png`.
- Readout-scale and hierarchy reference: `C:\\Users\\Tao\\AppData\\Local\\Temp\\codex-clipboard-43be4971-c0b6-4b13-a1ba-4fd6e3020ce2.png`.
- Authenticated preview: `http://127.0.0.1/cost/index`, optional `3D舱` mode, live authorized overview data.
- Responsive checks: `1440 × 1000`, `1024 × 900`, and `720 × 900` CSS viewports.

## Card correction

- The previous double-layer, front-facing amount-card geometry was the visible mismatch. Amount cards now use one taller rounded extruded body, a single pure-color face, a narrow darker side, controlled local shadow, and the prototype-like oblique pose.
- Amount-card faces use an unlit texture material so scene lighting cannot wash blue, green, or orange into a pale ceramic panel. White titles, larger tabular amounts, units, and the existing Element Plus money glyph remain deterministic texture content.
- Ratio cards now use a single ceramic-white extruded body with neutral sides, pale labels, dark percentages, formulas, and the requested colored upper-right relation glyph. The former colored frame, division badge, and progress rail are absent.
- Main amount cards remain larger than ratio cards, preserving the requested parent/child hierarchy while keeping all text inside the Three.js texture surface.
- Saturation was sampled from the supplied reference and applied as the scene source palette: blue `#3481F7`, green `#3CCB8B`, orange `#FF983B`, plus deep blue `#1555DA` and cyan `#4BCCF6` for the composition ring.
- Composition sectors now use an unlit exact-color top face and a 28% darker lit side face. The result retains the reference's saturated top surfaces without flattening the 3D thickness.

## Embedded composition readout

- P2 fixed: the previous pale form-like plaque compressed the full summary into one tiny sentence and visually detached it from the saturated scene.
- Follow-up P2 fixed: printing text onto the near-horizontal platform surface compressed it in perspective and allowed the blue trim to cross the glyphs. That unreadable treatment was removed.
- The circular platform remains approximately 12% wider, while its front apron now contains a recessed, camera-facing information window with a blue structural frame and pale ceramic display surface. It reads as part of the base rather than a floating seventh card.
- The primary title (`账面成本合计` or the active cost item), prominent amount, and optional percentage or reversal status have a protected clear area and are never crossed by the platform trim.
- The default readout title and amount were enlarged by roughly 35%, then vertically recentered to occupy the display surface. Hover state reserves a second line for percentage or reversal context without shrinking the primary values back to the earlier size.
- Desktop amount cards are approximately 10% narrower and 13% shorter; ratio cards are approximately 11% smaller. The fixed positions remain unchanged, preserving the business loop while reducing competition with the center.
- The composition ring outer radius increased from `6.65` to `7.35` and its usable radial width increased from `3.00` to `3.50`, making the real data visualization the dominant scene element without exceeding the enlarged platform.
- Real ring hover was verified to replace the default summary with the active item name, amount, and percentage while keeping the linked footer item synchronized.

## Motion and interaction correction

- Full mode keeps center rotation, low-amplitude model/ring movement, staggered card floating, pointer parallax, and spring-based card/sector responses.
- `跟随系统` and `精简` retain immediate hover and click behavior while suppressing continuous motion as selected.
- Hovering the real composition ring activated exactly one linked composition item, enlarged and lifted the matching sector, and updated the embedded base information strip.
- A real canvas click navigated to `/cost/ledger-composition-detail?from=overview&itemCode=501104&domainCode=MISSILE`.
- The base readout now redraws an existing CanvasTexture instead of recreating texture and geometry resources on each hover update.

## Responsive and regression review

- At `1440px`, the six fixed cards remain clear of the central ring and preserve the solid-main/white-secondary distinction.
- At `1024px`, the same scene remains readable with no overlap or horizontal overflow.
- Below `768px`, the scene cards remain hidden and the established two-column HTML metric grid preserves all six values and formulas.
- Cost type-check, targeted ESLint, and `git diff --check` passed; production build was intentionally not run.

## Four-domain switcher

- The 3D pod now exposes only the four primary domains in the fixed business order: launch vehicle, missile, satellite, and space security. Demo data no longer enters the 3D rotation when primary-domain data is available.
- Each selector shows the domain name plus its real contract amount and book cost, while the active domain continues to render the complete model, six metrics, and eight-item composition.
- The switcher uses four equal columns on desktop and a two-by-two grid below `1180px`; the compact layout was visually verified with all four domain summaries visible at once.
- Manual switching from space security to launch vehicle updated the heading and all six compact metrics to the selected domain's values. The 15-second cycle now uses the same four-domain sequence.

## Result

final result: passed

---

# Cost overview four independent WebGL pods QA

## Current architecture

- This section supersedes the earlier aggregate-center and domain-switcher experiments.
- `3D舱` now renders four independent formal-domain scenes in the fixed order `LAUNCH`, `MISSILE`, `SATELLITE`, `SPACE`; `DEMO` is excluded.
- Each scene owns one domain model, six CanvasTexture metric cards, one eight-item composition ring, one embedded base readout, its own raycaster/drag state, and its own WebGL lifecycle.
- The compact top strip aggregates only the authorized formal domains. It does not create a fifth scene or fabricate a missing-domain zero value.
- The `四舱总览 / 单舱轮转` control keeps the four-pod cockpit as the default while allowing the same scene to expand into a single-domain large-screen view. The most recent layout is stored separately from the existing overview-mode preference.
- Single-pod mode exposes a compact domain selector and rotates through `LAUNCH`, `MISSILE`, `SATELLITE`, `SPACE`, and `DEMO` every `15s`; pointer or keyboard interaction inside the pod pauses cycling, and reduced-motion mode disables it. The four-pod grid and aggregate strip remain limited to the four formal domains.

## Authenticated visual verification

- The redundant `八院成本驾驶舱` explanation toolbar was removed. Its motion control now sits beside the existing `经典 / 数据舱 / 3D舱` switch in the top summary bar.
- At desktop widths, each domain header is now an absolute transparent overlay (`rgba(0,0,0,0)`, no bottom border). The WebGL canvas begins at the pod top, so the center contract card remains visible behind the unused middle of the header while the title and actions stay at the left and right edges.
- The compact camera's vertical range increased from `10.6` to `11.4`; all four contract cards are fully visible rather than clipped at the scene boundary. Transparent-header business buttons were verified by opening the launch-domain unit-detail dialog.
- At `1440 × 1000`, the title row and aggregate strip meet with a measured `0px` gap. The grid resolves to two columns without horizontal overflow; the first pod row spans `y=238–610`, the second spans `y=620–992`, and the document height remains exactly `1000px`, so the enlarged pods fill one screen without clipping.
- The desktop scene height is derived from the available viewport height, while the `gridPod` camera switches to its closer framing above a `1.8` scene aspect ratio. This enlarges the ring, model, metric cards, and readout together rather than stretching an empty outer shell.
- CanvasTexture typography now fills the 3D cards more deliberately: amount-card labels use `74px`, values start at `184px`, and units use `46px`; rate-card labels use `56px`, values start at `124px`, and formulas use `34px`, with fit-to-width retained for long real values.
- Rate-card textures now place the metric label and percentage on the same baseline, with the calculation formula on a separate lower line. This gives the label more horizontal room without reducing the percentage hierarchy.
- Rate-card labels now use deep blue-gray `#30425f` at weight `800`, while formulas use `#52647d` at weight `750`; the formerly pale supporting copy remains legible after perspective scaling.
- In authenticated single-pod mode at `1440 × 1000`, the pod spans `y=238–998`, the scene host is `756px` tall, exactly one canvas is mounted, and the document has no horizontal overflow. Hiding the redundant domain-count tag in this mode keeps the top control row on one line.
- At `1024 × 900`, the grid still resolves to one `937px` column with four `560px` canvases and no horizontal overflow.
- At `390 × 844`, all four canvases remain available for the central models and rings, all `24` compact metric cells are present, scene cards are hidden below `560px`, and the portal reports no horizontal overflow.
- The authorized aggregate strip displayed contract `66,260`, received `49,150`, book cost `20,910`, received rate `74%`, usage rate `43%`, and execution rate `32%`.
- The eight-item footer card strip was removed from every pod. Eight-item amounts still drive the 3D ring, embedded readout, hover state, and sector drill-down without consuming dashboard height.

## Interaction and lifecycle verification

- Explicit `自动动效` now overrides the operating-system reduced-motion preference; the system preference is used only as the first unsaved default. Pointer presence no longer pauses idle rotation or floating, while drag, focus, hidden-tab, and off-screen controls remain intact.
- Two `1440 × 1000` captures taken `1.2s` apart differed across `121,087` PNG bytes; with the pointer inside the launch pod, two captures `1.1s` apart still differed across `121,158` bytes, confirming that automatic motion remains active in both states.
- A real satellite-sector click navigated to `/cost/ledger-composition-detail?from=overview&itemCode=501102&domainCode=SATELLITE`.
- A real space-security sector click navigated with `itemCode=501104&domainCode=SPACE`, confirming that scene context does not leak between pods.
- After the compact-layout change, a real launch-sector click still navigated with `itemCode=501102&domainCode=LAUNCH`.
- With reduced motion enabled, a real launch-sector click still navigated with `itemCode=501102&domainCode=LAUNCH`; continuous motion suppression does not disable picking.
- Switching `3D舱 → 经典 → 3D舱` produced canvas counts `4 → 0 → 4`.
- Single-pod automatic cycling was observed changing `导弹武器 → 卫星项目` within one `16s` verification window while the mounted canvas count remained `1`.
- The single-pod selector displayed all five authorized options, manual `演示领域` selection rendered its real metrics with one canvas, and a subsequent `空间安全 → 演示领域` automatic transition completed within `16s`.
- Browser console review found no new errors; only the pre-existing qiankun global-state deprecation warning remains.

## Result

final result: passed

---

# Cost overview WebGL interaction and composition correction QA

## Evidence

- Visual references: `C:\Users\Tao\AppData\Local\Temp\codex-clipboard-f134c2e5-bf87-42f0-b9f1-73c658021ed4.png`, `codex-clipboard-8b45532d-6d19-4169-b473-bdc24529e067.png`, and `codex-clipboard-3655c402-8a5e-40e6-b96b-400699125176.png`.
- Authenticated preview: `http://127.0.0.1/cost/index`, optional `3D舱` mode, live authorized overview data.
- Browser preference during interaction checks: `prefers-reduced-motion: reduce` enabled.
- Responsive checks: `1440 × 1000`, `1024 × 1000`, and `720 × 1000` CSS viewports.

## Interaction correction

- Reduced motion no longer disables the renderer's business interaction path. It disables idle rotation, floating and spring interpolation only; pointer-driven hover renders immediately.
- Ring hover activated the linked footer item and enlarged/lifted the matching 3D sector while updating the embedded base readout.
- A fresh click on the canvas, without relying on a stale hover value, navigated to `/cost/ledger-composition-detail?from=overview&itemCode=501101&domainCode=DEMO`.
- A `5px` drag threshold separates center rotation from click activation; pointer cancel and leave paths clear transient hover state.

## Visual and layout correction

- Six cards now use the requested fixed business loop: contract top, received rate upper-right, received amount right, usage rate lower-right, book cost lower-left, and execution rate left.
- Amount cards use complete blue/green/orange material faces with white embedded text. Ratio cards use ceramic-white faces, dark text, colored progress, and a neutral division symbol rather than a false trend arrow.
- Card shadows are now card-local and bounded, so they do not spread across the central composition ring.
- The floating composition plaque and all four orbit ornaments were removed. Composition text is embedded into the front edge of the central base and updates in place.
- Missile presentation is upright and no longer uses a horizontal cradle.

## Responsive and regression review

- At `1440px`, all six scene cards remain separated from the center safety area and the contract card is fully visible.
- At `1024px`, the same six-card ring remains readable without overlap or horizontal overflow.
- Below `768px`, scene cards are hidden and the existing two-column HTML metric grid remains the readable fallback; the central model and ring remain visible.
- Classic and SVG data-pod files were not modified in this correction.

## Result

final result: passed

---

# Cost overview optional WebGL 3D pod design QA

## Evidence

- Source prototype: `E:\Download\gemini-code-1788424047522.html`.
- Source SHA256: `DCB4E144087461A757504ED889386D12E32D328A89736045221135774B0F3F5C`.
- Implementation: authenticated local cost portal at `http://127.0.0.1/cost/index`, optional `3D舱` mode, real `/cost/overview/summary` data.
- Visual checks: `1440 × 1000`, `1024 × 900`, and `390 × 844` CSS viewports.

## Source-to-product translation

- Preserved the prototype's orthographic low-poly composition, ceramic panels, thick colored card bases, central cost ring, and four recognisable domain-model families.
- Removed prototype-only CDN imports, hard-coded demo amounts, three-item composition, mouse-following tooltip, and unrestricted global listeners.
- Replaced all displayed values with the current authorized domain data. Canvas-texture labels, values, units, formulas, and progress bars remain part of the 3D scene rather than floating DOM cards.

## Required surface review

- Typography and data clarity: passed. All six card textures remain readable at desktop and tablet widths; mobile uses the exact same shared metric calculation in an HTML grid.
- Spacing and hierarchy: passed. Amount cards remain primary, ratio cards secondary, and the central ring/model retain the visual focus without covering business actions.
- Colors and materials: passed. The scene stays within blue, green, orange, ceramic white, and semantic red for negative amounts.
- Model mapping: passed for launch vehicle, missile, satellite, space station, and demo/unknown-to-space-station fallback.
- Responsive behavior: passed with no document or page-container horizontal overflow at `1024` and `390` widths. The page's existing internal vertical scroll exposes the complete pod and eight-item strip.
- Mode isolation: passed. Repeated `3D舱 → 经典 → 3D舱 → 数据舱 → 3D舱` switching produced canvas counts `1 → 0 → 1 → 0 → 1`, confirming the optional scene mounts and unmounts with the selected mode.

## Interaction and accessibility

- Verified domain tabs, real-data refresh after domain changes, mobile metric fallback, scene actions, composition footer focus/hover synchronization, and the existing drill-down event contract.
- The WebGL canvas has a domain-specific accessible label; domain selectors, actions, and composition items remain keyboard-operable HTML controls.
- Reduced-motion, off-screen, hidden-tab, and pointer/focus pause paths are implemented without changing the classic or SVG data-pod behavior.

## Result

final result: passed
