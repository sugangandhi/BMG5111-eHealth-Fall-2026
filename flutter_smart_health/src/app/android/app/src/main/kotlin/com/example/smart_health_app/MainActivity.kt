package com.example.smart_health_app

import android.Manifest
import android.content.Intent
import android.content.pm.PackageManager
import android.media.MediaRecorder
import android.net.Uri
import android.os.Build
import android.os.Bundle
import android.os.Handler
import android.os.Looper
import android.provider.Settings
import android.speech.RecognitionListener
import android.speech.RecognizerIntent
import android.speech.SpeechRecognizer
import android.util.Base64
import androidx.core.app.ActivityCompat
import androidx.core.content.ContextCompat
import androidx.core.content.FileProvider
import androidx.core.content.pm.PackageInfoCompat
import androidx.health.connect.client.HealthConnectClient
import androidx.health.connect.client.aggregate.AggregateMetric
import androidx.health.connect.client.permission.HealthPermission
import androidx.health.connect.client.records.ActiveCaloriesBurnedRecord
import androidx.health.connect.client.records.DistanceRecord
import androidx.health.connect.client.records.ExerciseSessionRecord
import androidx.health.connect.client.records.HeartRateRecord
import androidx.health.connect.client.records.Record
import androidx.health.connect.client.records.RestingHeartRateRecord
import androidx.health.connect.client.records.SleepSessionRecord
import androidx.health.connect.client.records.StepsRecord
import androidx.health.connect.client.records.TotalCaloriesBurnedRecord
import androidx.health.connect.client.records.metadata.DataOrigin
import androidx.health.connect.client.request.AggregateRequest
import androidx.health.connect.client.request.ReadRecordsRequest
import androidx.health.connect.client.time.TimeRangeFilter
import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File
import java.time.Instant
import java.time.LocalDate
import java.time.ZoneId
import java.time.format.DateTimeFormatter
import java.time.temporal.ChronoUnit
import kotlin.math.max
import kotlin.reflect.KClass
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.launch

class MainActivity : FlutterFragmentActivity() {
    companion object {
        private const val HEALTH_APPS_CHANNEL = "com.example.smart_health_app/health_apps"
        private const val APP_UPDATER_CHANNEL = "com.example.smart_health_app/app_updater"
        private const val VOICE_SCRIBE_CHANNEL = "com.example.smart_health_app/voice_scribe"
        private const val REQUEST_RECORD_AUDIO = 4207
    }

    private val ioScope = CoroutineScope(SupervisorJob() + Dispatchers.IO)
    private val mainHandler = Handler(Looper.getMainLooper())
    private var voiceScribeChannel: MethodChannel? = null
    private var speechRecognizer: SpeechRecognizer? = null
    private var mediaRecorder: MediaRecorder? = null
    private var recordedAudioFile: File? = null
    private var isVoiceRecordingFallback = false
    private var latestPartialTranscript = ""
    private var pendingVoiceStartAction: (() -> Unit)? = null

    private data class HealthRecordProbeSpec(
        val label: String,
        val recordClass: KClass<out Record>,
        val coreRequired: Boolean,
    )

    private val probeSpecs = listOf(
        HealthRecordProbeSpec("Steps", StepsRecord::class, true),
        HealthRecordProbeSpec("Heart Rate", HeartRateRecord::class, true),
        HealthRecordProbeSpec("Active Calories", ActiveCaloriesBurnedRecord::class, true),
        HealthRecordProbeSpec("Total Calories", TotalCaloriesBurnedRecord::class, true),
        HealthRecordProbeSpec("Sleep", SleepSessionRecord::class, true),
        HealthRecordProbeSpec("Resting Heart Rate", RestingHeartRateRecord::class, false),
        HealthRecordProbeSpec("Distance", DistanceRecord::class, false),
        HealthRecordProbeSpec("Workouts", ExerciseSessionRecord::class, false),
    )

    private data class KnownHealthApp(
        val id: String,
        val sourceKey: String,
        val name: String,
        val packageName: String,
        val supportsHealthConnect: Boolean,
    )

    private val knownApps = listOf(
        KnownHealthApp("samsung_health", "samsung_health", "Samsung Health", "com.sec.android.app.shealth", true),
        KnownHealthApp("health_connect", "health_connect", "Health Connect", "com.google.android.apps.healthdata", true),
        KnownHealthApp("google_fit", "google_health", "Google Fit", "com.google.android.apps.fitness", true),
        KnownHealthApp("fitbit", "fitbit", "Fitbit", "com.fitbit.FitbitMobile", true),
        KnownHealthApp("garmin", "garmin", "Garmin Connect", "com.garmin.android.apps.connectmobile", true),
        KnownHealthApp("strava", "strava", "Strava", "com.strava", true),
        KnownHealthApp("oura", "oura", "Oura", "com.ouraring.oura", true),
        KnownHealthApp("whoop", "whoop", "WHOOP", "com.whoop.android", true),
        KnownHealthApp("withings", "withings", "Withings", "com.withings.wiscale2", true),
        KnownHealthApp("polar", "polar", "Polar Flow", "fi.polar.polarflow", true),
        KnownHealthApp("zepp", "zepp", "Zepp", "com.huami.watch.hmwatchmanager", true),
        KnownHealthApp("xiaomi_health", "xiaomi_health", "Mi Fitness", "com.mi.health", true),
        KnownHealthApp("xiaomi_fit", "xiaomi_health", "Zepp Life", "com.xiaomi.hm.health", true),
        KnownHealthApp("huawei_health", "huawei_health", "Huawei Health", "com.huawei.health", false),
    )

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            HEALTH_APPS_CHANNEL,
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                "detectInstalledHealthApps" -> result.success(detectInstalledHealthApps())
                "openHealthConnectSettings" -> {
                    val targetPkg = call.argument<String>("packageName")
                    result.success(openHealthConnectSettings(targetPkg))
                }
                "diagnoseHealthConnect" -> diagnoseHealthConnect(result)
                "aggregateHealthMetrics" -> {
                    val startEpochMs = (call.argument<Number>("startEpochMs"))?.toLong()
                    val endEpochMs = (call.argument<Number>("endEpochMs"))?.toLong()
                    val packages = call.argument<List<String>>("packageNames") ?: emptyList()
                    aggregateHealthMetrics(startEpochMs, endEpochMs, packages, result)
                }
                "openApp" -> {
                    val pkg = call.argument<String>("packageName") ?: ""
                    result.success(openPackage(pkg))
                }
                else -> result.notImplemented()
            }
        }

        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            APP_UPDATER_CHANNEL,
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                "getAppVersionInfo" -> result.success(getAppVersionInfo())
                "getUpdatesDir" -> {
                    val dir = File(cacheDir, "updates").apply { mkdirs() }
                    result.success(dir.absolutePath)
                }
                "canRequestPackageInstalls" -> result.success(canRequestPackageInstalls())
                "openUnknownAppSourcesSettings" -> result.success(openUnknownAppSourcesSettings())
                "installApk" -> {
                    val path = call.argument<String>("path") ?: ""
                    result.success(installApk(path))
                }
                else -> result.notImplemented()
            }
        }

        val voiceChannel = MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            VOICE_SCRIBE_CHANNEL,
        )
        voiceScribeChannel = voiceChannel
        voiceChannel.setMethodCallHandler { call, result ->
            when (call.method) {
                "startListening" -> {
                    startVoiceDictation()
                    result.success(true)
                }
                "stopListening" -> {
                    stopVoiceDictation()
                    result.success(true)
                }
                else -> result.notImplemented()
            }
        }
    }

    private fun isPackageInstalled(packageName: String): Boolean {
        return try {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
                packageManager.getPackageInfo(
                    packageName,
                    PackageManager.PackageInfoFlags.of(0),
                )
            } else {
                @Suppress("DEPRECATION")
                packageManager.getPackageInfo(packageName, 0)
            }
            true
        } catch (_: Exception) {
            false
        }
    }

    private fun resolveAppLabel(packageName: String): String {
        return try {
            val appInfo = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
                packageManager.getApplicationInfo(
                    packageName,
                    PackageManager.ApplicationInfoFlags.of(0),
                )
            } else {
                @Suppress("DEPRECATION")
                packageManager.getApplicationInfo(packageName, 0)
            }
            packageManager.getApplicationLabel(appInfo).toString()
        } catch (_: Exception) {
            packageName
        }
    }

    private fun queryDynamicHealthConnectApps(): Map<String, String> {
        val discovered = linkedMapOf<String, String>()
        val intents = listOf(
            Intent("androidx.health.ACTION_SHOW_PERMISSIONS_RATIONALE"),
            Intent("android.intent.action.VIEW_PERMISSION_USAGE").apply {
                addCategory("android.intent.category.HEALTH_PERMISSIONS")
            },
        )
        for (intent in intents) {
            val resolved = try {
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
                    packageManager.queryIntentActivities(
                        intent,
                        PackageManager.ResolveInfoFlags.of(PackageManager.MATCH_DEFAULT_ONLY.toLong()),
                    )
                } else {
                    @Suppress("DEPRECATION")
                    packageManager.queryIntentActivities(intent, PackageManager.MATCH_DEFAULT_ONLY)
                }
            } catch (_: Exception) {
                emptyList()
            }
            for (info in resolved) {
                val pkg = info.activityInfo?.packageName ?: continue
                if (pkg == applicationContext.packageName) continue
                if (!discovered.containsKey(pkg)) {
                    discovered[pkg] = resolveAppLabel(pkg)
                }
            }
        }
        return discovered
    }

    private fun detectInstalledHealthApps(): List<Map<String, Any>> {
        val output = mutableListOf<Map<String, Any>>()
        val seenPackages = hashSetOf<String>()

        for (app in knownApps) {
            val installed = when {
                app.packageName == "com.google.android.apps.healthdata" &&
                    Build.VERSION.SDK_INT >= Build.VERSION_CODES.UPSIDE_DOWN_CAKE -> true
                else -> isPackageInstalled(app.packageName)
            }
            if (installed) {
                seenPackages.add(app.packageName)
            }
            output.add(
                mapOf(
                    "id" to app.id,
                    "sourceKey" to app.sourceKey,
                    "name" to app.name,
                    "packageName" to app.packageName,
                    "installed" to installed,
                    "supportsHealthConnect" to app.supportsHealthConnect,
                    "detectedDynamically" to false,
                ),
            )
        }

        // Also include any dynamically discovered Health Connect partner apps on this device.
        for ((pkg, label) in queryDynamicHealthConnectApps()) {
            if (seenPackages.contains(pkg)) continue
            seenPackages.add(pkg)
            output.add(
                mapOf(
                    "id" to pkg,
                    "sourceKey" to "health_connect",
                    "name" to label,
                    "packageName" to pkg,
                    "installed" to true,
                    "supportsHealthConnect" to true,
                    "detectedDynamically" to true,
                ),
            )
        }

        return output
    }

    private fun diagnoseHealthConnect(result: MethodChannel.Result) {
        val sdkStatus = try {
            HealthConnectClient.getSdkStatus(applicationContext)
        } catch (_: Exception) {
            HealthConnectClient.SDK_UNAVAILABLE
        }
        if (sdkStatus != HealthConnectClient.SDK_AVAILABLE) {
            result.success(
                mapOf(
                    "sdkStatus" to sdkStatus,
                    "available" to false,
                    "grantedReadLabels" to emptyList<String>(),
                    "missingCorePermissions" to probeSpecs.filter { it.coreRequired }.map { it.label },
                    "records24hCount" to 0,
                    "records29dCount" to 0,
                    "todayAggregateSteps" to 0L,
                    "last29dAggregateSteps" to 0L,
                    "dataOrigins24h" to emptyMap<String, Int>(),
                    "dataOrigins29d" to emptyMap<String, Int>(),
                    "originLabels" to emptyMap<String, String>(),
                    "typeCounts29d" to emptyMap<String, Int>(),
                ),
            )
            return
        }

        ioScope.launch {
            val payload = try {
                val client = HealthConnectClient.getOrCreate(applicationContext)
                val granted = client.permissionController.getGrantedPermissions()
                val now = Instant.now()
                val start24h = now.minus(24, ChronoUnit.HOURS)
                val start29d = now.minus(29, ChronoUnit.DAYS)
                val startOfToday = LocalDate.now().atStartOfDay(ZoneId.systemDefault()).toInstant()

                val grantedLabels = mutableListOf<String>()
                val missingCore = mutableListOf<String>()
                val origins24h = linkedMapOf<String, Int>()
                val origins29d = linkedMapOf<String, Int>()
                val originLabels = linkedMapOf<String, String>()
                val typeCounts29d = linkedMapOf<String, Int>()
                var records24hCount = 0
                var records29dCount = 0
                var latestRecordEpochMs: Long? = null

                for (spec in probeSpecs) {
                    val perm = HealthPermission.getReadPermission(spec.recordClass)
                    if (!granted.contains(perm)) {
                        if (spec.coreRequired) missingCore.add(spec.label)
                        continue
                    }
                    grantedLabels.add(spec.label)

                    try {
                        var pageToken: String? = null
                        var typeCount = 0
                        for (page in 0 until 5) {
                            val req = ReadRecordsRequest(
                                recordType = spec.recordClass,
                                timeRangeFilter = TimeRangeFilter.between(start29d, now),
                                pageToken = pageToken,
                            )
                            val resp = client.readRecords(req)
                            for (rec in resp.records) {
                                typeCount++
                                records29dCount++
                                val pkg = rec.metadata.dataOrigin.packageName
                                origins29d[pkg] = (origins29d[pkg] ?: 0) + 1
                                if (pkg.isNotEmpty() && !originLabels.containsKey(pkg)) {
                                    originLabels[pkg] = resolveAppLabel(pkg)
                                }
                                val ts = when (rec) {
                                    is StepsRecord -> rec.endTime
                                    is HeartRateRecord -> rec.endTime
                                    is ActiveCaloriesBurnedRecord -> rec.endTime
                                    is TotalCaloriesBurnedRecord -> rec.endTime
                                    is SleepSessionRecord -> rec.endTime
                                    is DistanceRecord -> rec.endTime
                                    is ExerciseSessionRecord -> rec.endTime
                                    is RestingHeartRateRecord -> rec.time
                                    else -> null
                                }
                                if (ts != null) {
                                    val ms = ts.toEpochMilli()
                                    if (latestRecordEpochMs == null || ms > latestRecordEpochMs) {
                                        latestRecordEpochMs = ms
                                    }
                                    if (!ts.isBefore(start24h)) {
                                        records24hCount++
                                        origins24h[pkg] = (origins24h[pkg] ?: 0) + 1
                                    }
                                }
                            }
                            pageToken = resp.pageToken
                            if (pageToken.isNullOrEmpty()) break
                        }
                        if (typeCount > 0) {
                            typeCounts29d[spec.label] = typeCount
                        }
                    } catch (_: Exception) {
                        // Ignore per-record-type query errors during diagnostics.
                    }
                }

                var todayAggregateSteps = 0L
                var last29dAggregateSteps = 0L
                if (granted.contains(HealthPermission.getReadPermission(StepsRecord::class))) {
                    try {
                        val todayAgg = client.aggregate(
                            AggregateRequest(
                                metrics = setOf(StepsRecord.COUNT_TOTAL),
                                timeRangeFilter = TimeRangeFilter.between(startOfToday, now),
                            ),
                        )
                        todayAggregateSteps = todayAgg[StepsRecord.COUNT_TOTAL] ?: 0L
                    } catch (_: Exception) {}
                    try {
                        val totalAgg = client.aggregate(
                            AggregateRequest(
                                metrics = setOf(StepsRecord.COUNT_TOTAL),
                                timeRangeFilter = TimeRangeFilter.between(start29d, now),
                            ),
                        )
                        last29dAggregateSteps = totalAgg[StepsRecord.COUNT_TOTAL] ?: 0L
                    } catch (_: Exception) {}
                }

                mapOf(
                    "sdkStatus" to sdkStatus,
                    "available" to true,
                    "grantedPermissionCount" to granted.size,
                    "grantedReadLabels" to grantedLabels,
                    "missingCorePermissions" to missingCore,
                    "records24hCount" to records24hCount,
                    "records29dCount" to records29dCount,
                    "todayAggregateSteps" to todayAggregateSteps,
                    "last29dAggregateSteps" to last29dAggregateSteps,
                    "latestRecordEpochMs" to latestRecordEpochMs,
                    "dataOrigins24h" to origins24h,
                    "dataOrigins29d" to origins29d,
                    "originLabels" to originLabels,
                    "typeCounts29d" to typeCounts29d,
                )
            } catch (e: Exception) {
                mapOf(
                    "sdkStatus" to sdkStatus,
                    "available" to false,
                    "error" to (e.message ?: e.toString()),
                )
            }
            mainHandler.post { result.success(payload) }
        }
    }

    private fun aggregateHealthMetrics(
        startEpochMs: Long?,
        endEpochMs: Long?,
        packageNames: List<String>,
        result: MethodChannel.Result,
    ) {
        if (startEpochMs == null || endEpochMs == null || endEpochMs <= startEpochMs) {
            result.success(mapOf("available" to false, "reason" to "invalid_range"))
            return
        }
        val sdkStatus = try {
            HealthConnectClient.getSdkStatus(applicationContext)
        } catch (_: Exception) {
            HealthConnectClient.SDK_UNAVAILABLE
        }
        if (sdkStatus != HealthConnectClient.SDK_AVAILABLE) {
            result.success(mapOf("available" to false, "sdkStatus" to sdkStatus))
            return
        }

        ioScope.launch {
            val payload: Map<String, Any?> = try {
                val client = HealthConnectClient.getOrCreate(applicationContext)
                val granted = client.permissionController.getGrantedPermissions()
                val stepsGranted =
                    granted.contains(HealthPermission.getReadPermission(StepsRecord::class))
                val activeCalGranted =
                    granted.contains(HealthPermission.getReadPermission(ActiveCaloriesBurnedRecord::class))
                val totalCalGranted =
                    granted.contains(HealthPermission.getReadPermission(TotalCaloriesBurnedRecord::class))

                val metrics = mutableSetOf<AggregateMetric<*>>()
                if (stepsGranted) metrics.add(StepsRecord.COUNT_TOTAL)
                if (activeCalGranted) metrics.add(ActiveCaloriesBurnedRecord.ACTIVE_CALORIES_TOTAL)
                if (totalCalGranted) metrics.add(TotalCaloriesBurnedRecord.ENERGY_TOTAL)

                if (metrics.isEmpty()) {
                    mapOf("available" to true)
                } else {
                    val startInstant = Instant.ofEpochMilli(startEpochMs)
                    val endInstant = Instant.ofEpochMilli(endEpochMs)
                    val zone = ZoneId.systemDefault()
                    val endOfWindowDay = startInstant
                        .atZone(zone)
                        .toLocalDate()
                        .plusDays(1)
                        .atStartOfDay(zone)
                        .toInstant()
                    // Daily step/active-calorie summaries (e.g. Samsung Health's
                    // [00:00..24:00] bucket) extend to end-of-day; querying up to
                    // endOfWindowDay avoids fractionally clipping 158 steps to 10.
                    val activityEndInstant =
                        if (endInstant.isBefore(endOfWindowDay)) endOfWindowDay else endInstant
                    val origins = packageNames
                        .map { it.trim() }
                        .filter { it.isNotEmpty() }
                        .map { DataOrigin(it) }
                        .toSet()

                    val activityMetrics = mutableSetOf<AggregateMetric<*>>()
                    if (stepsGranted) activityMetrics.add(StepsRecord.COUNT_TOTAL)
                    if (activeCalGranted) activityMetrics.add(ActiveCaloriesBurnedRecord.ACTIVE_CALORIES_TOTAL)
                    val sameWindowForTotal = activityEndInstant == endInstant
                    if (totalCalGranted && sameWindowForTotal) {
                        activityMetrics.add(TotalCaloriesBurnedRecord.ENERGY_TOTAL)
                    }

                    val activityAgg = if (activityMetrics.isNotEmpty()) {
                        client.aggregate(
                            AggregateRequest(
                                metrics = activityMetrics,
                                timeRangeFilter = TimeRangeFilter.between(startInstant, activityEndInstant),
                                dataOriginFilter = origins,
                            ),
                        )
                    } else {
                        null
                    }
                    val totalCalAgg = if (totalCalGranted && !sameWindowForTotal) {
                        client.aggregate(
                            AggregateRequest(
                                metrics = setOf(TotalCaloriesBurnedRecord.ENERGY_TOTAL),
                                timeRangeFilter = TimeRangeFilter.between(startInstant, endInstant),
                                dataOriginFilter = origins,
                            ),
                        )
                    } else {
                        activityAgg
                    }

                    val stepsTotal: Long? =
                        if (stepsGranted) (activityAgg?.get(StepsRecord.COUNT_TOTAL) ?: 0L) else null
                    val activeCalTotal: Double? = if (activeCalGranted) {
                        activityAgg?.get(ActiveCaloriesBurnedRecord.ACTIVE_CALORIES_TOTAL)?.inKilocalories ?: 0.0
                    } else {
                        null
                    }
                    val totalCalTotal: Double? = if (totalCalGranted) {
                        totalCalAgg?.get(TotalCaloriesBurnedRecord.ENERGY_TOTAL)?.inKilocalories ?: 0.0
                    } else {
                        null
                    }

                    var strictSteps: Long? = if (stepsGranted) 0L else null
                    var crossMidnightCount = 0
                    var longCrossMidnightCount = 0
                    var strictRecordCount = 0
                    val stepsByOrigin = mutableMapOf<String, Long>()
                    val originLabels = mutableMapOf<String, String>()
                    val stepRecordSamples = mutableListOf<String>()

                    if (stepsGranted) {
                        try {
                            // Read across all origins so diagnostics always surface every
                            // Health Connect writer, while strict step math respects origins.
                            val allRecords = readStepsRecordsInRange(
                                client = client,
                                startInstant = startInstant,
                                endInstant = activityEndInstant,
                                origins = emptySet(),
                            )
                            val filterPackages = origins.map { it.packageName }.toSet()
                            val records = if (filterPackages.isEmpty()) {
                                allRecords
                            } else {
                                allRecords.filter { filterPackages.contains(it.metadata.dataOrigin.packageName) }
                            }
                            val strictRecords = mutableListOf<StepsRecord>()
                            val allSeenPackages = linkedSetOf<String>()
                            for (rec in allRecords) {
                                val pkg = rec.metadata.dataOrigin.packageName
                                if (pkg.isNotEmpty()) {
                                    allSeenPackages.add(pkg)
                                    if (!originLabels.containsKey(pkg)) {
                                        originLabels[pkg] = resolveAppLabel(pkg)
                                    }
                                }
                            }
                            for (rec in records) {
                                if (rec.startTime.isBefore(startInstant) && rec.endTime.isAfter(startInstant)) {
                                    crossMidnightCount++
                                    val durationMs = rec.endTime.toEpochMilli() - rec.startTime.toEpochMilli()
                                    if (durationMs >= 7_200_000L) {
                                        longCrossMidnightCount++
                                    }
                                } else if (!rec.startTime.isBefore(startInstant)) {
                                    strictRecords.add(rec)
                                }
                            }
                            strictRecordCount = strictRecords.size
                            strictSteps = computeDeduplicatedStepsTotal(strictRecords)

                            val timeFmt = DateTimeFormatter.ofPattern("MM/dd HH:mm").withZone(zone)
                            allRecords
                                .sortedByDescending { it.count }
                                .take(6)
                                .forEach { rec ->
                                    val pkg = rec.metadata.dataOrigin.packageName
                                    val label = originLabels[pkg] ?: resolveAppLabel(pkg)
                                    val crossTag = if (rec.startTime.isBefore(startInstant)) " [pre-midnight]" else ""
                                    stepRecordSamples.add(
                                        "$label: ${rec.count} (${timeFmt.format(rec.startTime)}..${timeFmt.format(rec.endTime)})$crossTag",
                                    )
                                }

                            for (pkg in filterPackages) {
                                if (!originLabels.containsKey(pkg)) {
                                    originLabels[pkg] = resolveAppLabel(pkg)
                                }
                            }
                            if (allSeenPackages.size > 1 ||
                                (filterPackages.isNotEmpty() && allSeenPackages.isNotEmpty())) {
                                for (pkg in (filterPackages + allSeenPackages).take(8)) {
                                    if (filterPackages.size == 1 && pkg == filterPackages.first() && stepsTotal != null) {
                                        stepsByOrigin[pkg] = stepsTotal
                                        continue
                                    }
                                    try {
                                        val pkgAgg = client.aggregate(
                                            AggregateRequest(
                                                metrics = setOf(StepsRecord.COUNT_TOTAL),
                                                timeRangeFilter = TimeRangeFilter.between(startInstant, activityEndInstant),
                                                dataOriginFilter = setOf(DataOrigin(pkg)),
                                            ),
                                        )
                                        stepsByOrigin[pkg] = pkgAgg[StepsRecord.COUNT_TOTAL] ?: 0L
                                    } catch (_: Exception) {}
                                }
                            } else if (allSeenPackages.size == 1) {
                                val onlyPkg = allSeenPackages.first()
                                if (filterPackages.isEmpty() && stepsTotal != null) {
                                    stepsByOrigin[onlyPkg] = stepsTotal
                                } else {
                                    try {
                                        val pkgAgg = client.aggregate(
                                            AggregateRequest(
                                                metrics = setOf(StepsRecord.COUNT_TOTAL),
                                                timeRangeFilter = TimeRangeFilter.between(startInstant, activityEndInstant),
                                                dataOriginFilter = setOf(DataOrigin(onlyPkg)),
                                            ),
                                        )
                                        stepsByOrigin[onlyPkg] = pkgAgg[StepsRecord.COUNT_TOTAL] ?: 0L
                                    } catch (_: Exception) {}
                                }
                            } else if (filterPackages.size == 1 && stepsTotal != null) {
                                val pkg = filterPackages.first()
                                stepsByOrigin[pkg] = stepsTotal
                            }
                        } catch (_: Exception) {
                            strictSteps = stepsTotal
                        }
                    }

                    mapOf(
                        "available" to true,
                        "steps" to stepsTotal,
                        "strictSteps" to strictSteps,
                        "crossMidnightRecords" to crossMidnightCount,
                        "longCrossMidnightRecords" to longCrossMidnightCount,
                        "strictStepRecords" to strictRecordCount,
                        "activeCalories" to activeCalTotal,
                        "totalCalories" to totalCalTotal,
                        "stepsByOrigin" to stepsByOrigin,
                        "originLabels" to originLabels,
                        "stepRecordSamples" to stepRecordSamples,
                    )
                }
            } catch (e: Exception) {
                mapOf(
                    "available" to false,
                    "error" to (e.message ?: e.toString()),
                )
            }
            mainHandler.post { result.success(payload) }
        }
    }

    private suspend fun readStepsRecordsInRange(
        client: HealthConnectClient,
        startInstant: Instant,
        endInstant: Instant,
        origins: Set<DataOrigin>,
    ): List<StepsRecord> {
        val records = mutableListOf<StepsRecord>()
        var pageToken: String? = null
        for (page in 0 until 20) {
            val resp = client.readRecords(
                ReadRecordsRequest(
                    recordType = StepsRecord::class,
                    timeRangeFilter = TimeRangeFilter.between(startInstant, endInstant),
                    dataOriginFilter = origins,
                    pageToken = pageToken,
                ),
            )
            records.addAll(resp.records)
            pageToken = resp.pageToken
            if (pageToken == null) break
        }
        return records
    }

    private fun computeDeduplicatedStepsTotal(records: List<StepsRecord>): Long {
        if (records.isEmpty()) return 0L
        data class StepSpan(
            val streamKey: String,
            val startMs: Long,
            val endMs: Long,
            val count: Long,
        )

        val seen = HashSet<String>(records.size)
        val spans = ArrayList<StepSpan>(records.size)
        for (rec in records) {
            if (rec.count <= 0L) continue
            val sMs = rec.startTime.toEpochMilli()
            val eMs = rec.endTime.toEpochMilli()
            if (eMs <= sMs) continue
            val streamKey =
                "${rec.metadata.dataOrigin.packageName}|${rec.metadata.device?.model ?: ""}|${rec.metadata.recordingMethod}"
            val dedupKey = "$streamKey|$sMs|$eMs|${rec.count}"
            if (seen.add(dedupKey)) {
                spans.add(StepSpan(streamKey, sMs, eMs, rec.count))
            }
        }
        if (spans.isEmpty()) return 0L
        spans.sortWith(compareBy<StepSpan> { it.startMs }.thenBy { it.endMs })

        fun maxStreamSum(items: List<StepSpan>): Long {
            if (items.isEmpty()) return 0L
            val byEnd = items.sortedBy { it.endMs }
            val ends = LongArray(byEnd.size) { byEnd[it].endMs }
            val dp = LongArray(byEnd.size)
            for (i in byEnd.indices) {
                val cur = byEnd[i]
                var lo = 0
                var hi = i - 1
                var prev = -1
                while (lo <= hi) {
                    val mid = (lo + hi) ushr 1
                    if (ends[mid] <= cur.startMs) {
                        prev = mid
                        lo = mid + 1
                    } else {
                        hi = mid - 1
                    }
                }
                val take = cur.count + if (prev >= 0) dp[prev] else 0L
                val skip = if (i > 0) dp[i - 1] else 0L
                dp[i] = max(take, skip)
            }
            return dp[byEnd.size - 1]
        }

        fun flushComponent(items: List<StepSpan>): Long {
            val byStream = items.groupBy { it.streamKey }
            var best = 0L
            for (streamItems in byStream.values) {
                best = max(best, maxStreamSum(streamItems))
            }
            return best
        }

        var total = 0L
        var comp = mutableListOf(spans[0])
        var compMaxEnd = spans[0].endMs
        for (i in 1 until spans.size) {
            val item = spans[i]
            if (item.startMs < compMaxEnd) {
                comp.add(item)
                if (item.endMs > compMaxEnd) compMaxEnd = item.endMs
            } else {
                total += flushComponent(comp)
                comp = mutableListOf(item)
                compMaxEnd = item.endMs
            }
        }
        total += flushComponent(comp)
        return total
    }

    private fun openHealthConnectSettings(targetPackageName: String? = null): Boolean {
        val permPkg = targetPackageName?.takeIf { it.isNotBlank() } ?: applicationContext.packageName
        val candidates = listOf(
            Intent("android.health.connect.action.MANAGE_HEALTH_PERMISSIONS").apply {
                putExtra(Intent.EXTRA_PACKAGE_NAME, permPkg)
            },
            Intent("android.health.connect.action.MANAGE_HEALTH_PERMISSIONS").apply {
                putExtra(Intent.EXTRA_PACKAGE_NAME, applicationContext.packageName)
            },
            Intent(HealthConnectClient.ACTION_HEALTH_CONNECT_SETTINGS),
            Intent("android.health.connect.action.HEALTH_CONNECT_SETTINGS"),
            Intent("androidx.health.ACTION_HEALTH_CONNECT_SETTINGS"),
        )
        for (intent in candidates) {
            intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
            try {
                if (intent.resolveActivity(packageManager) != null) {
                    startActivity(intent)
                    return true
                }
            } catch (_: Exception) {}
        }
        if (openPackage("com.google.android.apps.healthdata")) {
            return true
        }
        return try {
            startActivity(
                Intent(
                    Intent.ACTION_VIEW,
                    Uri.parse("https://play.google.com/store/apps/details?id=com.google.android.apps.healthdata"),
                ).addFlags(Intent.FLAG_ACTIVITY_NEW_TASK),
            )
            true
        } catch (_: Exception) {
            false
        }
    }

    private fun openPackage(packageName: String): Boolean {
        if (packageName.isBlank()) return false
        return try {
            val launch = packageManager.getLaunchIntentForPackage(packageName) ?: return false
            launch.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
            startActivity(launch)
            true
        } catch (_: Exception) {
            false
        }
    }

    private fun getAppVersionInfo(): Map<String, Any> {
        return try {
            val info = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
                packageManager.getPackageInfo(
                    packageName,
                    PackageManager.PackageInfoFlags.of(0),
                )
            } else {
                @Suppress("DEPRECATION")
                packageManager.getPackageInfo(packageName, 0)
            }
            mapOf(
                "versionName" to (info.versionName ?: "1.0.0"),
                "versionCode" to PackageInfoCompat.getLongVersionCode(info).toInt(),
            )
        } catch (_: Exception) {
            mapOf("versionName" to "1.0.0", "versionCode" to 1)
        }
    }

    private fun canRequestPackageInstalls(): Boolean {
        return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            packageManager.canRequestPackageInstalls()
        } else {
            true
        }
    }

    private fun openUnknownAppSourcesSettings(): Boolean {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) return true
        return try {
            val intent = Intent(
                Settings.ACTION_MANAGE_UNKNOWN_APP_SOURCES,
                Uri.parse("package:$packageName"),
            ).addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
            startActivity(intent)
            true
        } catch (_: Exception) {
            false
        }
    }

    private fun installApk(filePath: String): Boolean {
        if (filePath.isBlank()) return false
        val apkFile = File(filePath)
        if (!apkFile.exists() || apkFile.length() == 0L) return false
        return try {
            val uri = FileProvider.getUriForFile(
                this,
                "${applicationContext.packageName}.fileprovider",
                apkFile,
            )
            val intent = Intent(Intent.ACTION_VIEW).apply {
                setDataAndType(uri, "application/vnd.android.package-archive")
                addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
                addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
            }
            startActivity(intent)
            true
        } catch (_: Exception) {
            false
        }
    }

    private fun startVoiceDictation() {
        if (isVoiceRecordingFallback) {
            stopVoiceDictation()
            return
        }
        ensureRecordAudioPermission {
            // Use MediaRecorder (.m4a) -> OpenAI whisper-1 as primary for single-pass
            // zero-repetition clinical dictation, avoiding SpeechRecognizer duplicates.
            startAudioCaptureFallback()
        }
    }

    private fun ensureRecordAudioPermission(onGranted: () -> Unit) {
        if (ContextCompat.checkSelfPermission(this, Manifest.permission.RECORD_AUDIO) ==
            PackageManager.PERMISSION_GRANTED
        ) {
            onGranted()
            return
        }
        pendingVoiceStartAction = onGranted
        ActivityCompat.requestPermissions(
            this,
            arrayOf(Manifest.permission.RECORD_AUDIO),
            REQUEST_RECORD_AUDIO,
        )
    }

    override fun onRequestPermissionsResult(
        requestCode: Int,
        permissions: Array<out String>,
        grantResults: IntArray,
    ) {
        super.onRequestPermissionsResult(requestCode, permissions, grantResults)
        if (requestCode == REQUEST_RECORD_AUDIO) {
            val action = pendingVoiceStartAction
            pendingVoiceStartAction = null
            if (grantResults.isNotEmpty() && grantResults[0] == PackageManager.PERMISSION_GRANTED) {
                action?.invoke()
            } else {
                emitVoiceStatus(
                    "error",
                    "Microphone permission is required for voice dictation.",
                )
            }
        }
    }

    private fun startNativeSpeechRecognizer() {
        mainHandler.post {
            try {
                speechRecognizer?.destroy()
                speechRecognizer = null
                isVoiceRecordingFallback = false
                latestPartialTranscript = ""

                val recognizer = SpeechRecognizer.createSpeechRecognizer(this)
                speechRecognizer = recognizer
                recognizer.setRecognitionListener(object : RecognitionListener {
                    override fun onReadyForSpeech(params: Bundle?) {
                        emitVoiceStatus("listening", "")
                    }

                    override fun onBeginningOfSpeech() {}
                    override fun onRmsChanged(rmsdB: Float) {}
                    override fun onBufferReceived(buffer: ByteArray?) {}
                    override fun onEndOfSpeech() {}

                    override fun onError(error: Int) {
                        if (latestPartialTranscript.isNotBlank()) {
                            emitVoiceResult(latestPartialTranscript, "")
                            latestPartialTranscript = ""
                        }
                        if (error == SpeechRecognizer.ERROR_NO_MATCH ||
                            error == SpeechRecognizer.ERROR_SPEECH_TIMEOUT
                        ) {
                            emitVoiceStatus("stopped", "")
                        } else if (error == SpeechRecognizer.ERROR_INSUFFICIENT_PERMISSIONS) {
                            emitVoiceStatus(
                                "error",
                                "Microphone permission denied. Allow mic access in Settings.",
                            )
                        } else {
                            // Release SpeechRecognizer mic hold before falling back to MediaRecorder + Whisper.
                            try {
                                speechRecognizer?.destroy()
                            } catch (_: Exception) {}
                            speechRecognizer = null
                            startAudioCaptureFallback()
                        }
                    }

                    override fun onResults(results: Bundle?) {
                        val matches = results
                            ?.getStringArrayList(SpeechRecognizer.RESULTS_RECOGNITION)
                        val spoken = matches?.firstOrNull()?.trim().orEmpty()
                        val resolved = if (spoken.isNotEmpty()) spoken else latestPartialTranscript
                        latestPartialTranscript = ""
                        if (resolved.isNotEmpty()) {
                            emitVoiceResult(resolved, "")
                        }
                        emitVoiceStatus("stopped", "")
                    }

                    override fun onPartialResults(partialResults: Bundle?) {
                        val matches = partialResults
                            ?.getStringArrayList(SpeechRecognizer.RESULTS_RECOGNITION)
                        val partial = matches?.firstOrNull()?.trim().orEmpty()
                        if (partial.isNotEmpty()) {
                            latestPartialTranscript = partial
                            emitVoiceResult("", partial)
                        }
                    }

                    override fun onEvent(eventType: Int, params: Bundle?) {}
                })

                val intent = Intent(RecognizerIntent.ACTION_RECOGNIZE_SPEECH).apply {
                    putExtra(
                        RecognizerIntent.EXTRA_LANGUAGE_MODEL,
                        RecognizerIntent.LANGUAGE_MODEL_FREE_FORM,
                    )
                    putExtra(RecognizerIntent.EXTRA_LANGUAGE, "en-US")
                    putExtra(RecognizerIntent.EXTRA_PARTIAL_RESULTS, true)
                }
                emitVoiceStatus("listening", "")
                recognizer.startListening(intent)
            } catch (_: Exception) {
                startAudioCaptureFallback()
            }
        }
    }

    private fun startAudioCaptureFallback() {
        mainHandler.post {
            try {
                releaseMediaRecorder()
                val outFile = File(cacheDir, "voice_note.m4a")
                if (outFile.exists()) outFile.delete()
                val recorder = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
                    MediaRecorder(this)
                } else {
                    @Suppress("DEPRECATION")
                    MediaRecorder()
                }
                recorder.setAudioSource(MediaRecorder.AudioSource.MIC)
                recorder.setOutputFormat(MediaRecorder.OutputFormat.MPEG_4)
                recorder.setAudioEncoder(MediaRecorder.AudioEncoder.AAC)
                recorder.setAudioChannels(1)
                recorder.setAudioSamplingRate(16000)
                recorder.setAudioEncodingBitRate(64000)
                recorder.setOutputFile(outFile.absolutePath)
                recorder.prepare()
                recorder.start()
                mediaRecorder = recorder
                recordedAudioFile = outFile
                isVoiceRecordingFallback = true
                emitVoiceStatus("recording", "")
            } catch (e: Exception) {
                isVoiceRecordingFallback = false
                if (SpeechRecognizer.isRecognitionAvailable(this)) {
                    startNativeSpeechRecognizer()
                } else {
                    emitVoiceStatus("error", "Could not start microphone: ${e.message ?: "error"}")
                }
            }
        }
    }

    private fun stopVoiceDictation() {
        mainHandler.post {
            if (isVoiceRecordingFallback) {
                isVoiceRecordingFallback = false
                val targetFile = recordedAudioFile
                try {
                    mediaRecorder?.stop()
                } catch (_: Exception) {}
                releaseMediaRecorder()
                if (targetFile != null && targetFile.exists() && targetFile.length() >= 400L) {
                    emitVoiceStatus("transcribing", "")
                    ioScope.launch {
                        try {
                            val bytes = targetFile.readBytes()
                            val b64 = Base64.encodeToString(bytes, Base64.NO_WRAP)
                            targetFile.delete()
                            mainHandler.post {
                                voiceScribeChannel?.invokeMethod(
                                    "onAudioCaptured",
                                    mapOf("base64" to b64, "filename" to "voice_note.m4a"),
                                )
                            }
                        } catch (e: Exception) {
                            mainHandler.post {
                                emitVoiceStatus("error", "Audio capture failed: ${e.message ?: "error"}")
                            }
                        }
                    }
                } else {
                    targetFile?.delete()
                    emitVoiceStatus("stopped", "")
                }
                return@post
            }

            try {
                speechRecognizer?.stopListening()
            } catch (_: Exception) {
                emitVoiceStatus("stopped", "")
            }
        }
    }

    private fun releaseMediaRecorder() {
        try {
            mediaRecorder?.reset()
            mediaRecorder?.release()
        } catch (_: Exception) {}
        mediaRecorder = null
    }

    private fun emitVoiceResult(finalResult: String, interimResult: String) {
        mainHandler.post {
            voiceScribeChannel?.invokeMethod(
                "onSpeechResult",
                mapOf("finalResult" to finalResult, "interimResult" to interimResult),
            )
        }
    }

    private fun emitVoiceStatus(status: String, message: String) {
        mainHandler.post {
            voiceScribeChannel?.invokeMethod(
                "onSpeechStatus",
                mapOf("status" to status, "message" to message),
            )
        }
    }

    override fun onDestroy() {
        speechRecognizer?.destroy()
        speechRecognizer = null
        releaseMediaRecorder()
        super.onDestroy()
    }
}
