package com.example.smart_health_app

import android.content.Intent
import android.content.pm.PackageManager
import android.net.Uri
import android.os.Build
import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterFragmentActivity() {
    companion object {
        private const val HEALTH_APPS_CHANNEL = "com.example.smart_health_app/health_apps"
    }

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
                "openHealthConnectSettings" -> result.success(openHealthConnectSettings())
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

    private fun openHealthConnectSettings(): Boolean {
        val candidates = listOf(
            Intent("android.health.connect.action.MANAGE_HEALTH_PERMISSIONS").apply {
                putExtra(Intent.EXTRA_PACKAGE_NAME, applicationContext.packageName)
            },
            Intent("androidx.health.ACTION_HEALTH_CONNECT_SETTINGS"),
        )
        for (intent in candidates) {
            intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
            if (intent.resolveActivity(packageManager) != null) {
                startActivity(intent)
                return true
            }
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
