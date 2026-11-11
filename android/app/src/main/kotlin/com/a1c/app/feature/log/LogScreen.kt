package com.a1c.app.feature.log

import androidx.compose.foundation.BorderStroke
import androidx.compose.foundation.Canvas
import androidx.compose.foundation.background
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.text.KeyboardOptions
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Check
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.geometry.CornerRadius
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.geometry.Size
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.drawText
import androidx.compose.ui.text.rememberTextMeasurer
import androidx.compose.ui.text.TextStyle
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.input.KeyboardType
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.compose.ui.hapticfeedback.HapticFeedbackType
import androidx.compose.ui.platform.LocalHapticFeedback
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.semantics
import com.a1c.app.data.DoseLogResult
import com.a1c.app.data.HealthConnectState
import com.a1c.app.data.LogData
import com.a1c.app.data.api.ActivityDto
import com.a1c.app.data.api.DoseDto
import com.a1c.app.data.api.GlucoseReadingDto
import com.a1c.app.data.api.NutritionDto
import com.a1c.app.ui.theme.Accent
import com.a1c.app.ui.theme.AccentDim
import com.a1c.app.ui.theme.Exercise
import com.a1c.app.ui.theme.Food
import com.a1c.app.ui.theme.Glucose
import com.a1c.app.ui.theme.InsulinFast
import com.a1c.app.ui.theme.InsulinOnBoard
import com.a1c.app.ui.theme.InsulinSlow
import com.a1c.app.ui.theme.OnSurfaceDim
import kotlinx.coroutines.delay
import java.time.Instant
import java.time.LocalDate
import java.time.ZoneId
import java.time.format.DateTimeFormatter
import androidx.compose.ui.graphics.Path
import androidx.compose.ui.graphics.StrokeCap
import androidx.compose.ui.graphics.drawscope.Stroke
import androidx.compose.ui.platform.LocalLifecycleOwner
import androidx.lifecycle.Lifecycle
import androidx.lifecycle.LifecycleEventObserver

private val timeFormat = DateTimeFormatter.ofPattern("EEE d MMM · HH:mm").withZone(ZoneId.systemDefault())
private val dayLabel = DateTimeFormatter.ofPattern("d MMM")

@Composable
fun LogScreen(
    data: LogData,
    onLogDose: (Int, String, (DoseLogResult) -> Unit) -> Unit,
    onRefresh: () -> Unit,
    onRequestHealthPermissions: () -> Unit = {},
) {
    var unitsText by remember { mutableStateOf("") }
    var kind by remember { mutableStateOf<String?>(null) }
    var message by remember { mutableStateOf<String?>(null) }
    var messageIsError by remember { mutableStateOf(false) }
    var now by remember { mutableStateOf(Instant.now()) }
    val haptic = LocalHapticFeedback.current

    val lifecycleOwner = LocalLifecycleOwner.current
    DisposableEffect(lifecycleOwner) {
        val observer = androidx.lifecycle.LifecycleEventObserver { _, event ->
            if (event == Lifecycle.Event.ON_RESUME) {
                now = Instant.now()
                onRefresh()
            }
        }
        lifecycleOwner.lifecycle.addObserver(observer)
        onDispose { lifecycleOwner.lifecycle.removeObserver(observer) }
    }

    val units = unitsText.toIntOrNull()
    val canSave = units != null && units > 0 && kind != null

    // Success feedback clears itself; errors stay until the next action.
    LaunchedEffect(message) {
        if (message != null && !messageIsError) {
            delay(2500)
            message = null
        }
    }

    Column(
        modifier = Modifier
            .fillMaxSize()
            .background(MaterialTheme.colorScheme.background)
            .verticalScroll(rememberScrollState())
            .padding(20.dp)
    ) {
        // Row 1 — tiny, dimmed context. Time on the left, A1C:Total on the
        // right. Weight is gone from the UI (still in the database/API).
        Row(
            modifier = Modifier.fillMaxWidth(),
            horizontalArrangement = Arrangement.SpaceBetween,
        ) {
            Text(
                text = timeFormat.format(now),
                style = MaterialTheme.typography.bodySmall,
                color = MaterialTheme.colorScheme.onSurfaceVariant,
            )
            data.settings?.a1cTotal?.let {
                Text(
                    text = "A1C:Total %.1f".format(it),
                    style = MaterialTheme.typography.bodySmall,
                    color = MaterialTheme.colorScheme.onSurfaceVariant,
                )
            }
        }

        Spacer(Modifier.height(14.dp))

        // Row 2 — one card per metric, each in its metric color
        // (docs/design-system.md): current glucose, last insulin, and
        // rapid insulin on board (NovoRapid, 4 h linear decay).
        Row(
            modifier = Modifier.fillMaxWidth(),
            horizontalArrangement = Arrangement.spacedBy(10.dp),
        ) {
            MetricCard(
                label = "Glucose",
                color = Glucose,
                modifier = Modifier.weight(1f),
            ) {
                val latest = data.glucose.lastOrNull()
                if (latest == null) {
                    Text("—", style = MaterialTheme.typography.titleLarge, color = Glucose)
                    Text("no CGM", style = MaterialTheme.typography.bodySmall, color = MaterialTheme.colorScheme.onSurfaceVariant)
                } else {
                    val age = latest.ageMinutes(now)
                    val stale = age < 0 || age > 30
                    val arrow = directionArrow(latest.direction)
                    Text(
                        text = "%.1f".format(latest.mmolL ?: latest.sgv / 18.0),
                        style = MaterialTheme.typography.titleLarge,
                        fontWeight = FontWeight.SemiBold,
                        color = if (stale) MaterialTheme.colorScheme.onSurfaceVariant else Glucose,
                    )
                    Text(
                        text = buildString {
                            append("mmol/L")
                            if (arrow.isNotEmpty()) append(" $arrow")
                            when {
                                age < 0 -> {}
                                age < 1 -> append(" · now")
                                age < 60 -> append(" · ${age}m")
                                else -> append(" · ${age / 60}h")
                            }
                        },
                        style = MaterialTheme.typography.bodySmall,
                        color = MaterialTheme.colorScheme.onSurfaceVariant,
                    )
                }
            }

            val lastDose = data.doses.lastOrNull()
            MetricCard(
                label = "Last insulin",
                color = if (lastDose?.kind == "slow") InsulinSlow else InsulinFast,
                modifier = Modifier.weight(1f),
            ) {
                if (lastDose == null) {
                    Text("—", style = MaterialTheme.typography.titleLarge, color = MaterialTheme.colorScheme.onSurfaceVariant)
                    Text("none yet", style = MaterialTheme.typography.bodySmall, color = MaterialTheme.colorScheme.onSurfaceVariant)
                } else {
                    val kindName = if (lastDose.kind == "slow") data.settings?.slowName ?: "Slow" else data.settings?.fastName ?: "Fast"
                    Text(
                        text = "${lastDose.units} u",
                        style = MaterialTheme.typography.titleLarge,
                        fontWeight = FontWeight.SemiBold,
                        color = if (lastDose.kind == "slow") InsulinSlow else InsulinFast,
                    )
                    Text(
                        text = "$kindName · ${timeAgoShort(lastDose, now)}",
                        style = MaterialTheme.typography.bodySmall,
                        color = MaterialTheme.colorScheme.onSurfaceVariant,
                    )
                }
            }

            MetricCard(
                label = "On board",
                color = InsulinOnBoard,
                modifier = Modifier.weight(1f),
            ) {
                val iob = insulinOnBoard(data.doses, now)
                Text(
                    text = "%.1f u".format(iob),
                    style = MaterialTheme.typography.titleLarge,
                    fontWeight = FontWeight.SemiBold,
                    color = if (iob > 0) InsulinOnBoard else MaterialTheme.colorScheme.onSurfaceVariant,
                )
                Text(
                    text = "4 h decay",
                    style = MaterialTheme.typography.bodySmall,
                    color = MaterialTheme.colorScheme.onSurfaceVariant,
                )
            }
        }

        Spacer(Modifier.height(14.dp))

        // Row 3 — the entry controls, all on one line: units field (two
        // digits is the whole use case), N (NovoRapid), R (Ryzodeg), save.
        Row(
            modifier = Modifier.fillMaxWidth(),
            horizontalArrangement = Arrangement.spacedBy(10.dp),
            verticalAlignment = Alignment.CenterVertically,
        ) {
            OutlinedTextField(
                value = unitsText,
                onValueChange = { value -> if (value.all { it.isDigit() }) unitsText = value.take(2) },
                label = { Text("u") },
                keyboardOptions = KeyboardOptions(keyboardType = KeyboardType.Number),
                singleLine = true,
                textStyle = LocalTextStyle.current.copy(
                    fontSize = 24.sp,
                    fontWeight = FontWeight.SemiBold,
                    textAlign = TextAlign.Center,
                ),
                modifier = Modifier
                    .width(96.dp)
                    .heightIn(min = 64.dp)
                    // The visible label is the compact unit suffix; the
                    // accessible name carries the meaning.
                    .semantics { contentDescription = "Insulin units" },
            )
            ChoiceChip(
                selected = kind == "fast",
                label = data.settings?.fastName ?: "Fast",
                // The visible label is the configured insulin name (IA §Log,
                // slice-3 contract); compact pen letters were brand-specific.
                description = data.settings?.fastName ?: "Fast",
                color = InsulinFast,
                modifier = Modifier.weight(1f),
            ) { kind = "fast" }
            ChoiceChip(
                selected = kind == "slow",
                label = data.settings?.slowName ?: "Slow",
                description = data.settings?.slowName ?: "Slow",
                color = InsulinSlow,
                modifier = Modifier.weight(1f),
            ) { kind = "slow" }
            FilledIconButton(
                onClick = {
                    val selectedKind = kind
                    val unitsValue = units
                    if (selectedKind != null && unitsValue != null && unitsValue > 0) {
                        // Instant feedback: clear the form right away (the dose is
                        // persisted locally by the repository before any network
                        // round-trip), then confirm via the callback.
                        unitsText = ""
                        kind = null
                        haptic.performHapticFeedback(HapticFeedbackType.LongPress)
                        onLogDose(unitsValue, selectedKind) { result ->
                            when (result) {
                                is DoseLogResult.Success -> {
                                    messageIsError = false
                                    message = "✓ Saved $unitsValue u $selectedKind"
                                }
                                is DoseLogResult.Offline -> {
                                    messageIsError = false
                                    message = "✓ Saved offline — will sync when online"
                                }
                                is DoseLogResult.Failure -> {
                                    messageIsError = true
                                    message = result.message
                                }
                            }
                        }
                    }
                },
                enabled = canSave,
                modifier = Modifier.size(52.dp),
                shape = RoundedCornerShape(12.dp),
                colors = IconButtonDefaults.filledIconButtonColors(
                    containerColor = Accent,
                    contentColor = MaterialTheme.colorScheme.onPrimary,
                    disabledContainerColor = MaterialTheme.colorScheme.surfaceVariant,
                    disabledContentColor = MaterialTheme.colorScheme.onSurfaceVariant,
                ),
            ) {
                Icon(Icons.Filled.Check, contentDescription = "Save dose")
            }
        }

        message?.let {
            Text(
                text = it,
                color = if (messageIsError) MaterialTheme.colorScheme.error else MaterialTheme.colorScheme.primary,
                style = MaterialTheme.typography.bodyMedium,
                fontWeight = if (messageIsError) FontWeight.Normal else FontWeight.SemiBold,
                modifier = Modifier.padding(top = 10.dp),
            )
        }

        if (data.pendingCount > 0) {
            Surface(
                shape = RoundedCornerShape(8.dp),
                color = MaterialTheme.colorScheme.surfaceVariant,
                modifier = Modifier.padding(top = 10.dp),
            ) {
                Text(
                    text = "⏳ ${data.pendingCount} pending sync",
                    style = MaterialTheme.typography.bodySmall,
                    color = MaterialTheme.colorScheme.onSurfaceVariant,
                    modifier = Modifier.padding(horizontal = 10.dp, vertical = 6.dp),
                )
            }
        }

        Spacer(Modifier.height(28.dp))
        Text(
            text = "Daily totals",
            style = MaterialTheme.typography.titleMedium,
            color = MaterialTheme.colorScheme.onBackground,
        )
        Spacer(Modifier.height(12.dp))
        if (data.loadError != null && data.dailyTotals.isEmpty() && data.doses.isEmpty() && data.pendingCount == 0) {
            ErrorState(
                message = data.loadError,
                onRetry = onRefresh,
            )
        } else {
            DailyTotalsGraph(
                totals = data.dailyTotals,
                fastName = data.settings?.fastName ?: "Fast",
                slowName = data.settings?.slowName ?: "Slow",
            )
        }
        Spacer(Modifier.height(24.dp))

        GlucoseCard(
            glucose = data.glucose,
            doses = data.doses,
            days = data.days,
            activities = data.activities,
            nutrition = data.nutrition,
            healthConnect = data.healthConnect,
            healthRead = data.healthRead,
            timezone = data.settings?.timezone,
            onRequestHealthPermissions = onRequestHealthPermissions,
        )

        Spacer(Modifier.height(24.dp))

        Text(
            text = "Recent doses",
            style = MaterialTheme.typography.titleMedium,
            color = MaterialTheme.colorScheme.onBackground,
        )
        Spacer(Modifier.height(8.dp))
        when {
            data.loadError != null && data.doses.isEmpty() && data.pendingCount == 0 ->
                ErrorState(
                    message = data.loadError,
                    onRetry = onRefresh,
                )
            data.doses.isEmpty() -> EmptyState(text = "No doses logged yet.")
            else ->
            data.doses.takeLast(10).reversed().forEach { dose ->
                val kindLabel = when (dose.kind) {
                    "fast" -> data.settings?.fastName ?: "Fast"
                    else -> data.settings?.slowName ?: "Slow"
                }
                Row(
                    modifier = Modifier
                        .fillMaxWidth()
                        .padding(vertical = 6.dp),
                    horizontalArrangement = Arrangement.SpaceBetween,
                ) {
                    Text(
                        text = kindLabel,
                        color = if (dose.kind == "fast") InsulinFast else MaterialTheme.colorScheme.onSurfaceVariant,
                        fontWeight = FontWeight.Medium,
                    )
                    Text("${dose.units} u", color = MaterialTheme.colorScheme.onBackground)
                    Text(
                        text = timeFormat.format(Instant.parse(dose.takenAt ?: dose.createdAt)) +
                            if (dose.id < 0) " · pending" else "",
                        color = MaterialTheme.colorScheme.onSurfaceVariant,
                        fontSize = 13.sp,
                    )
                }
            }
        }
        Spacer(Modifier.height(24.dp))
    }
}

/** One metric card: colored label on top, big value, dimmed detail. */
@Composable
private fun MetricCard(
    label: String,
    color: Color,
    modifier: Modifier = Modifier,
    content: @Composable ColumnScope.() -> Unit,
) {
    Surface(
        shape = RoundedCornerShape(14.dp),
        color = MaterialTheme.colorScheme.surface,
        border = BorderStroke(1.dp, color.copy(alpha = 0.45f)),
        modifier = modifier,
    ) {
        Column(
            modifier = Modifier.padding(horizontal = 12.dp, vertical = 10.dp),
        ) {
            Text(
                text = label,
                style = MaterialTheme.typography.labelSmall,
                color = color,
                maxLines = 1,
            )
            Spacer(Modifier.height(4.dp))
            content()
        }
    }
}

/** Last dose's age in short form ("12m", "3h"). */
private fun timeAgoShort(dose: DoseDto, now: Instant): String {
    val t = runCatching { Instant.parse(dose.takenAt ?: dose.createdAt) }.getOrNull()
        ?: return ""
    val minutes = (now.toEpochMilli() - t.toEpochMilli()) / 60_000
    return when {
        minutes < 1 -> "now"
        minutes < 60 -> "${minutes}m"
        else -> "${minutes / 60}h"
    }
}

/**
 * Rapid insulin on board (NovoRapid / insulin aspart): linear decay over a
 * 4 h duration of insulin action. EMA monograph: onset 10–20 min, peak
 * 1–3 h, duration 3–5 h — 4 h is the standard clinical approximation.
 * Only fast (N) doses count for now; Ryzodeg IOB comes later.
 */
private const val RAPID_DIA_HOURS = 4.0

private fun insulinOnBoard(doses: List<DoseDto>, now: Instant): Double =
    doses.sumOf { dose ->
        if (dose.kind != "fast") return@sumOf 0.0
        val t = runCatching { Instant.parse(dose.takenAt ?: dose.createdAt) }.getOrNull()
            ?: return@sumOf 0.0
        val elapsedH = (now.toEpochMilli() - t.toEpochMilli()) / 3_600_000.0
        if (elapsedH < 0 || elapsedH >= RAPID_DIA_HOURS) 0.0
        else dose.units * (1.0 - elapsedH / RAPID_DIA_HOURS)
    }

@Composable
private fun EmptyState(text: String) {
    Surface(
        shape = RoundedCornerShape(16.dp),
        color = MaterialTheme.colorScheme.surface,
        modifier = Modifier.fillMaxWidth(),
    ) {
        Column(
            modifier = Modifier
                .fillMaxWidth()
                .padding(vertical = 32.dp),
            horizontalAlignment = Alignment.CenterHorizontally,
        ) {
            Text(
                text = "·",
                style = MaterialTheme.typography.headlineMedium,
                color = AccentDim,
            )
            Spacer(Modifier.height(8.dp))
            Text(
                text = text,
                color = MaterialTheme.colorScheme.onSurfaceVariant,
                style = MaterialTheme.typography.bodyMedium,
            )
        }
    }
}

@Composable
private fun ErrorState(message: String, onRetry: () -> Unit) {
    Surface(
        shape = RoundedCornerShape(16.dp),
        color = MaterialTheme.colorScheme.surface,
        modifier = Modifier.fillMaxWidth(),
    ) {
        Column(
            modifier = Modifier
                .fillMaxWidth()
                .padding(vertical = 32.dp, horizontal = 24.dp),
            horizontalAlignment = Alignment.CenterHorizontally,
        ) {
            Text(
                text = "⚠",
                style = MaterialTheme.typography.headlineMedium,
                color = MaterialTheme.colorScheme.error,
            )
            Spacer(Modifier.height(8.dp))
            Text(
                text = message,
                color = MaterialTheme.colorScheme.onSurfaceVariant,
                style = MaterialTheme.typography.bodyMedium,
                textAlign = TextAlign.Center,
            )
            Spacer(Modifier.height(16.dp))
            OutlinedButton(
                onClick = onRetry,
                shape = RoundedCornerShape(12.dp),
            ) {
                Text("Retry")
            }
        }
    }
}

/** Chart axis: the date matters — a 24 h window crosses midnight. */
private val axisTimeFormat = DateTimeFormatter.ofPattern("d MMM HH:mm").withZone(ZoneId.systemDefault())

/** Nightscout direction names → arrows. */
private fun directionArrow(direction: String?): String = when (direction) {
    "DoubleUp" -> "↑↑"
    "SingleUp" -> "↑"
    "FortyFiveUp" -> "↗"
    "Flat" -> "→"
    "FortyFiveDown" -> "↘"
    "SingleDown" -> "↓"
    "DoubleDown" -> "↓↓"
    else -> ""
}

private fun GlucoseReadingDto.ageMinutes(now: Instant): Long =
    runCatching { (now.toEpochMilli() - Instant.parse(time).toEpochMilli()) / 60_000 }
        .getOrDefault(-1)

@Composable
private fun GlucoseCard(
    glucose: List<GlucoseReadingDto>,
    doses: List<DoseDto>,
    days: List<com.a1c.app.data.api.DayDto>,
    activities: List<ActivityDto>,
    nutrition: List<NutritionDto>,
    healthConnect: HealthConnectState,
    healthRead: com.a1c.app.data.HealthReadResult?,
    timezone: String?,
    onRequestHealthPermissions: () -> Unit,
) {
    Surface(
        shape = RoundedCornerShape(16.dp),
        color = MaterialTheme.colorScheme.surface,
        modifier = Modifier.fillMaxWidth(),
    ) {
        Column(modifier = Modifier.padding(16.dp)) {
            Text(
                text = "Glucose · last 24 h",
                style = MaterialTheme.typography.titleMedium,
                color = MaterialTheme.colorScheme.onBackground,
            )
            Spacer(Modifier.height(12.dp))
            if (glucose.size < 2) {
                Text(
                    "Waiting for glucose data — connect xDrip to the A1See API.",
                    color = MaterialTheme.colorScheme.onSurfaceVariant,
                )
            } else {
                GlucoseChart(glucose, doses, activities, nutrition, modifier = Modifier.fillMaxWidth())
                Spacer(Modifier.height(10.dp))
                Row(modifier = Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.SpaceBetween) {
                    Text(axisTimeFormat.format(Instant.parse(glucose.first().time)), color = MaterialTheme.colorScheme.onSurfaceVariant, fontSize = 10.sp)
                    Text("target 3.9–10 mmol/L", color = MaterialTheme.colorScheme.onSurfaceVariant, fontSize = 10.sp)
                    Text(axisTimeFormat.format(Instant.parse(glucose.last().time)), color = MaterialTheme.colorScheme.onSurfaceVariant, fontSize = 10.sp)
                }
                Spacer(Modifier.height(8.dp))
                // Two deliberate rows: three context metrics, then the two
                // dose kinds. A single row clips or wraps "slow ▼" at the edge.
                Column(verticalArrangement = Arrangement.spacedBy(4.dp)) {
                    Row(
                        modifier = Modifier.fillMaxWidth(),
                        horizontalArrangement = Arrangement.spacedBy(12.dp),
                    ) {
                        LegendDot(Glucose, "glucose")
                        LegendDot(Food, "food")
                        LegendDot(Exercise, "exercise")
                    }
                    Row(
                        modifier = Modifier.fillMaxWidth(),
                        horizontalArrangement = Arrangement.spacedBy(12.dp),
                    ) {
                        LegendDot(InsulinFast, "fast ▲")
                        LegendDot(InsulinSlow, "slow ▼")
                    }
                }
            }
            Spacer(Modifier.height(14.dp))
            TodayVsStandard(days = days, timezone = timezone)
            // Health Connect entry point + slice-6 diagnostic, kept compact.
            when (healthConnect) {
                is HealthConnectState.NeedsPermissions -> TextButton(
                    onClick = onRequestHealthPermissions,
                    contentPadding = PaddingValues(horizontal = 4.dp, vertical = 0.dp),
                    modifier = Modifier.height(28.dp),
                ) {
                    Text("Connect Health", fontSize = 12.sp, color = Accent)
                }
                is HealthConnectState.Unavailable, is HealthConnectState.UpdateRequired ->
                    Text(
                        "Health Connect unavailable",
                        fontSize = 11.sp,
                        color = MaterialTheme.colorScheme.onSurfaceVariant,
                    )
                else -> {}
            }
            // Temporary slice-6 diagnostic: what the reader saw this refresh.
            val readSummary = healthRead?.summary ?: "no read yet"
            Text(
                text = readSummary,
                fontSize = 9.sp,
                color = MaterialTheme.colorScheme.onSurfaceVariant,
                maxLines = 2,
            )
        }
    }
}

/**
 * Today's metrics, each measured against its standard (docs/design-system.md):
 * bar in the metric's own color, value vs goal. Standards: 2 000 kcal/day,
 * 20 min exercise; insulin has no universal target, so it is measured
 * against the 14-day average. Over/under is carried by the number, never
 * by recoloring the bar red.
 */
@Composable
private fun TodayVsStandard(days: List<com.a1c.app.data.api.DayDto>, timezone: String?) {
    // "Today" is the server's day boundary (settings.timezone), not the
    // phone's. They differ when travelling, which would zero the bars.
    val zone = remember(timezone) {
        runCatching { ZoneId.of(timezone ?: "") }.getOrDefault(ZoneId.systemDefault())
    }
    val today = LocalDate.now(zone).toString()
    val todayRow = days.lastOrNull { it.date == today }
    val window = days.takeLast(14)
    val avgFast = if (window.isEmpty()) 0f else window.sumOf { it.fastUnits }.toFloat() / window.size
    val avgSlow = if (window.isEmpty()) 0f else window.sumOf { it.slowUnits }.toFloat() / window.size

    Column(modifier = Modifier.fillMaxWidth(), verticalArrangement = Arrangement.spacedBy(8.dp)) {
        MetricRow(
            label = "Kcal",
            valueText = "${todayRow?.caloriesKcal ?: 0} / 2 000 kcal",
            fraction = (todayRow?.caloriesKcal ?: 0) / 2000f,
            color = Food,
        )
        MetricRow(
            label = "Exercise",
            valueText = "${todayRow?.exerciseMin ?: 0} / 20 min",
            fraction = (todayRow?.exerciseMin ?: 0) / 20f,
            color = Exercise,
        )
        MetricRow(
            label = "Fast",
            valueText = "${todayRow?.fastUnits ?: 0} u · avg %.1f".format(avgFast),
            fraction = if (avgFast > 0) (todayRow?.fastUnits ?: 0) / avgFast else 0f,
            color = InsulinFast,
        )
        MetricRow(
            label = "Slow",
            valueText = "${todayRow?.slowUnits ?: 0} u · avg %.1f".format(avgSlow),
            fraction = if (avgSlow > 0) (todayRow?.slowUnits ?: 0) / avgSlow else 0f,
            color = InsulinSlow,
        )
        // Carbs standard: 45% of the 2 000 kcal goal = 225 g/day (ADA
        // macro pattern for an adult male at this calorie target).
        MetricRow(
            label = "Carbs",
            valueText = "${todayRow?.carbsG ?: 0} / 225 g",
            fraction = (todayRow?.carbsG ?: 0) / 225f,
            color = Food,
        )
    }
}

/** One metric row: fixed-width label, bar in the metric color, value text. */
@Composable
private fun MetricRow(label: String, valueText: String, fraction: Float, color: Color) {
    Row(
        modifier = Modifier.fillMaxWidth(),
        verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.spacedBy(10.dp),
    ) {
        Text(
            text = label,
            fontSize = 11.sp,
            color = MaterialTheme.colorScheme.onSurfaceVariant,
            modifier = Modifier.width(56.dp),
        )
        Box(
            modifier = Modifier
                .weight(1f)
                .height(6.dp)
                .background(MaterialTheme.colorScheme.surfaceVariant, RoundedCornerShape(3.dp)),
        ) {
            Box(
                modifier = Modifier
                    .fillMaxWidth(fraction.coerceIn(0f, 1f))
                    .height(6.dp)
                    .background(color, RoundedCornerShape(3.dp)),
            )
        }
        Text(
            text = valueText,
            fontSize = 11.sp,
            color = MaterialTheme.colorScheme.onSurface,
            modifier = Modifier.width(110.dp),
            textAlign = TextAlign.End,
        )
    }
}

@Composable
private fun GlucoseChart(
    readings: List<GlucoseReadingDto>,
    doses: List<DoseDto>,
    activities: List<ActivityDto>,
    nutrition: List<NutritionDto>,
    modifier: Modifier = Modifier,
) {
    val mmol = readings.map { it.mmolL ?: it.sgv / 18.0 }
    val times = readings.map { Instant.parse(it.time).toEpochMilli() }
    val t0 = times.first()
    val t1 = times.last()
    val span = (t1 - t0).coerceAtLeast(1)
    val lo = (mmol.min() - 0.5).coerceAtLeast(2.0)
    val hi = (mmol.max() + 0.5).coerceAtLeast(lo + 2.0)
    val bandTop = 10.0.coerceAtMost(hi)
    val bandBottom = 3.9.coerceAtLeast(lo)

    // Context markers, clipped to the visible window.
    val exerciseBands = activities.mapNotNull {
        val start = runCatching { Instant.parse(it.startedAt).toEpochMilli() }.getOrNull() ?: return@mapNotNull null
        val end = runCatching { Instant.parse(it.endedAt).toEpochMilli() }.getOrNull() ?: return@mapNotNull null
        val x0 = ((start - t0).toFloat() / span).coerceIn(0f, 1f)
        val x1 = ((end - t0).toFloat() / span).coerceIn(0f, 1f)
        if (x1 - x0 < 0.002f) null else x0 to x1
    }
    val foodDots = nutrition.mapNotNull {
        val t = runCatching { Instant.parse(it.takenAt).toEpochMilli() }.getOrNull() ?: return@mapNotNull null
        if (t < t0 || t > t1) null else (t - t0).toFloat() / span
    }
    // Doses in the visible window, split by kind. Effective time is the
    // real injection time (taken_at) when present, else creation time.
    val doseMarkers = doses.mapNotNull { dose ->
        val t = runCatching {
            Instant.parse(dose.takenAt ?: dose.createdAt).toEpochMilli()
        }.getOrNull() ?: return@mapNotNull null
        if (t < t0 || t > t1) null else (t - t0).toFloat() / span to dose.kind
    }

    Row(modifier = modifier.fillMaxWidth()) {
        // Y scale in mmol/L: honest axis labels instead of an unlabelled curve.
        Column(
            modifier = Modifier.width(34.dp).height(140.dp),
            verticalArrangement = Arrangement.SpaceBetween,
            horizontalAlignment = Alignment.End,
        ) {
            Text("%.1f".format(hi), fontSize = 9.sp, color = MaterialTheme.colorScheme.onSurfaceVariant)
            Text("%.1f".format((hi + lo) / 2), fontSize = 9.sp, color = MaterialTheme.colorScheme.onSurfaceVariant)
            Text("%.1f".format(lo), fontSize = 9.sp, color = MaterialTheme.colorScheme.onSurfaceVariant)
        }

        Canvas(modifier = Modifier.weight(1f).height(140.dp)) {
        val pad = 2.dp.toPx()
        fun y(v: Double): Float {
            val frac = ((v - lo) / (hi - lo)).coerceIn(0.0, 1.0)
            return (size.height - pad) - (frac * (size.height - 2 * pad)).toFloat()
        }
        fun x(frac: Float): Float = frac * size.width

        // Exercise sessions: shaded full-height bands (they have duration and
        // their glucose effect lingers — a point would lie about that).
        exerciseBands.forEach { (x0, x1) ->
            drawRect(
                color = Exercise.copy(alpha = 0.18f),
                topLeft = Offset(x(x0), 0f),
                size = Size(x(x1) - x(x0), size.height),
            )
        }

        // Target band 3.9–10 mmol/L
        drawRoundRect(
            color = Glucose.copy(alpha = 0.10f),
            topLeft = Offset(0f, y(bandTop)),
            size = Size(size.width, y(bandBottom) - y(bandTop)),
            cornerRadius = CornerRadius(6f, 6f),
        )

        // Curve
        val path = Path().apply {
            times.forEachIndexed { i, t ->
                val px = ((t - t0).toFloat() / span) * size.width
                if (i == 0) moveTo(px, y(mmol[i])) else lineTo(px, y(mmol[i]))
            }
        }
        drawPath(path, color = Glucose, style = Stroke(width = 2.5.dp.toPx(), cap = StrokeCap.Round))

        // Food dots on the curve at intake time (linear between readings).
        foodDots.forEach { frac ->
            val target = t0 + (frac * span).toLong()
            val glucoseY = interpolateY(times, mmol, target)?.let { y(it) } ?: return@forEach
            drawCircle(
                color = Food,
                radius = 3.dp.toPx(),
                center = Offset(x(frac), glucoseY),
            )
        }

        // Dose markers: fast ▲ pinned to the top edge, slow ▼ to the bottom
        // edge — position carries the kind, color confirms it.
        doseMarkers.forEach { (frac, kind) ->
            val cx = x(frac)
            val r = 4.dp.toPx()
            if (kind == "fast") {
                val top = y(hi - 0.05) + r
                val tri = Path().apply {
                    moveTo(cx, top - r)
                    lineTo(cx - r, top + r)
                    lineTo(cx + r, top + r)
                    close()
                }
                drawPath(tri, color = InsulinFast)
            } else {
                val bottom = y(lo + 0.05) - r
                val tri = Path().apply {
                    moveTo(cx, bottom + r)
                    lineTo(cx - r, bottom - r)
                    lineTo(cx + r, bottom - r)
                    close()
                }
                drawPath(tri, color = InsulinSlow)
            }
        }

        // Latest point
        val lastX = ((times.last() - t0).toFloat() / span) * size.width
        drawCircle(color = Glucose, radius = 4.dp.toPx(), center = Offset(lastX, y(mmol.last())))
        }
    }
}

/** Glucose value at [target] by linear interpolation between bracketing readings. */
private fun interpolateY(times: List<Long>, mmol: List<Double>, target: Long): Double? {
    if (times.isEmpty()) return null
    if (target <= times.first()) return mmol.first()
    if (target >= times.last()) return mmol.last()
    val nextIdx = times.indexOfFirst { it > target }
    if (nextIdx <= 0) return mmol.first()
    val prevIdx = nextIdx - 1
    val t0 = times[prevIdx]
    val t1 = times[nextIdx]
    if (t1 == t0) return mmol[nextIdx]
    val frac = (target - t0).toDouble() / (t1 - t0)
    return mmol[prevIdx] + frac * (mmol[nextIdx] - mmol[prevIdx])
}

@Composable
private fun ChoiceChip(
    selected: Boolean,
    label: String,
    modifier: Modifier = Modifier,
    color: Color = Accent,
    description: String? = null,
    onClick: () -> Unit,
) {
    Surface(
        onClick = onClick,
        shape = RoundedCornerShape(12.dp),
        color = if (selected) color else MaterialTheme.colorScheme.surfaceVariant,
        modifier = modifier
            .height(52.dp)
            .then(
                if (description != null) Modifier.semantics { contentDescription = description }
                else Modifier
            ),
    ) {
        Box(contentAlignment = Alignment.Center) {
            Text(
                text = label,
                color = if (selected) MaterialTheme.colorScheme.onPrimary else MaterialTheme.colorScheme.onSurface,
                fontWeight = FontWeight.SemiBold,
                fontSize = 13.sp,
                maxLines = 1,
                overflow = TextOverflow.Ellipsis,
                textAlign = TextAlign.Center,
                modifier = Modifier.padding(horizontal = 6.dp),
            )
        }
    }
}

@Composable
private fun DailyTotalsGraph(totals: List<com.a1c.app.data.api.DailyTotalDto>, fastName: String, slowName: String) {
    val recent = totals.takeLast(14)
    Surface(
        shape = RoundedCornerShape(16.dp),
        color = MaterialTheme.colorScheme.surface,
        modifier = Modifier.fillMaxWidth(),
    ) {
        Column(modifier = Modifier.padding(16.dp)) {
            if (recent.isEmpty()) {
                Column(
                    modifier = Modifier.fillMaxWidth().padding(vertical = 24.dp),
                    horizontalAlignment = Alignment.CenterHorizontally,
                ) {
                    Text(
                        "Log your first dose to see the graph.",
                        color = MaterialTheme.colorScheme.onSurfaceVariant,
                    )
                }
            } else {
                val max = maxOf(recent.maxOf { it.fastUnits }, recent.maxOf { it.slowUnits }).coerceAtLeast(1)
                val textMeasurer = rememberTextMeasurer()
                Canvas(modifier = Modifier.fillMaxWidth().height(150.dp)) {
                    val slot = size.width / recent.size
                    val slowBarWidth = slot * 0.72f
                    val fastBarWidth = slot * 0.34f
                    val chartHeight = size.height - 24.dp.toPx()
                    recent.forEachIndexed { index, day ->
                        val slowHeight = (day.slowUnits.toFloat() / max) * chartHeight
                        val slowX = index * slot + (slot - slowBarWidth) / 2
                        if (day.slowUnits > 0) {
                            drawRoundRect(
                                color = InsulinSlow,
                                topLeft = Offset(slowX, size.height - slowHeight),
                                size = Size(slowBarWidth, slowHeight),
                                cornerRadius = CornerRadius(7f, 7f),
                            )
                        }
                        val fastHeight = (day.fastUnits.toFloat() / max) * chartHeight
                        val fastX = index * slot + (slot - fastBarWidth) / 2
                        if (day.fastUnits > 0) {
                            drawRoundRect(
                                color = InsulinFast,
                                topLeft = Offset(fastX, size.height - fastHeight),
                                size = Size(fastBarWidth, fastHeight),
                                cornerRadius = CornerRadius(7f, 7f),
                            )
                            val label = textMeasurer.measure(
                                day.fastUnits.toString(),
                                style = TextStyle(color = InsulinFast, fontSize = 11.sp, fontWeight = FontWeight.SemiBold),
                            )
                            drawText(
                                textLayoutResult = label,
                                topLeft = Offset(fastX + fastBarWidth / 2 - label.size.width / 2f, size.height - fastHeight - label.size.height - 4f),
                            )
                        }
                    }
                }
                Spacer(Modifier.height(8.dp))
                Row(modifier = Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.SpaceBetween) {
                    Text(LocalDate.parse(recent.first().date).format(dayLabel), color = MaterialTheme.colorScheme.onSurfaceVariant, fontSize = 11.sp)
                    Text(LocalDate.parse(recent.last().date).format(dayLabel), color = MaterialTheme.colorScheme.onSurfaceVariant, fontSize = 11.sp)
                }
                Spacer(Modifier.height(10.dp))
                Row(horizontalArrangement = Arrangement.spacedBy(16.dp)) {
                    LegendDot(InsulinFast, "Fast · $fastName")
                    LegendDot(InsulinSlow, "Slow · $slowName")
                }
            }
        }
    }
}

@Composable
private fun LegendDot(color: Color, label: String) {
    Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(6.dp)) {
        Box(
            modifier = Modifier
                .size(10.dp)
                .background(color, RoundedCornerShape(3.dp)),
        )
        Text(label, color = MaterialTheme.colorScheme.onSurfaceVariant, fontSize = 12.sp, maxLines = 1)
    }
}
