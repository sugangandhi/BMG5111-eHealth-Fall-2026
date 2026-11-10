package com.example.smart_health_app

import android.content.Intent
import android.content.pm.PackageManager
import android.net.Uri
import android.os.Build
import android.os.Handler
import android.os.Looper
import androidx.health.connect.client.HealthConnectClient
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
import androidx.health.connect.client.request.AggregateRequest
import androidx.health.connect.client.request.ReadRecordsRequest
import androidx.health.connect.client.time.TimeRangeFilter
import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.time.Instant
import java.time.LocalDate
import java.time.ZoneId
import java.time.temporal.ChronoUnit
import kotlin.reflect.KClass
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.launch

class MainActivity : FlutterFragmentActivity() {
    companion object {
        private const val HEALTH_APPS_CHANNEL = "com.example.smart_health_app/health_apps"
    }

    private val ioScope = CoroutineScope(SupervisorJob() + Dispatchers.IO)
    private val mainHandler = Handler(Looper.getMainLooper())

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
                "openApp" -> {
                    val pkg = call.argument<String>("packageName") ?: ""
                    result.success(openPackage(pkg))
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
}
