package org.haxe.lime

import android.app.Activity
import android.content.Context
import android.content.Intent
import android.content.pm.PackageInfo
import android.os.Build
import android.os.Bundle
import android.os.Process
import android.util.Log
import androidx.activity.ComponentActivity
import androidx.activity.compose.setContent
import androidx.compose.foundation.BorderStroke
import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.text.selection.SelectionContainer
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.rounded.Close
import androidx.compose.material.icons.rounded.ErrorOutline
import androidx.compose.material.icons.rounded.ExpandLess
import androidx.compose.material.icons.rounded.ExpandMore
import androidx.compose.material.icons.rounded.Refresh
import androidx.compose.material3.Button
import androidx.compose.material3.ButtonDefaults
import androidx.compose.material3.Card
import androidx.compose.material3.CardDefaults
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.OutlinedButton
import androidx.compose.material3.Surface
import androidx.compose.material3.Text
import androidx.compose.material3.Typography
import androidx.compose.material3.darkColorScheme
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.font.FontFamily
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import java.io.File
import java.text.SimpleDateFormat
import java.util.Date
import java.util.Locale
import kotlin.system.exitProcess

object LimeCrashHandler {
	private const val TAG = "LimeCrashHandler"
	private const val CRASH_FILE = "lime_last_crash.txt"
	private const val MAX_REPORT_CHARS = 60000

	const val EXTRA_CRASH_FILE = "org.haxe.lime.extra.CRASH_FILE"

	@Volatile
	private var installed = false

	@Volatile
	private var crashContext: Context? = null

	@JvmStatic
	fun install(activity: Activity) {
		val appContext = activity.applicationContext
		crashContext = appContext
		if (installed) return
		installed = true

		Thread.setDefaultUncaughtExceptionHandler { thread, throwable ->
			try {
				launchCrashActivity(appContext, buildReport(appContext, thread, throwable))
			} catch (handlerError: Throwable) {
				Log.e(TAG, "Crash recovery activity could not be launched.", handlerError)
			} finally {
				Process.killProcess(Process.myPid())
				exitProcess(10)
			}
		}
	}

	@JvmStatic
	fun showHaxeCrash(title: String?, report: String?) {
		val context = crashContext ?: return
		val timestamp = SimpleDateFormat("yyyy-MM-dd HH:mm:ss.SSS Z", Locale.US).format(Date())
		val formattedReport = buildString {
			appendLine("Time: $timestamp")
			appendLine("Package: ${context.packageName}")
			appendLine("Source: Haxe crash handler")
			if (!title.isNullOrBlank()) appendLine("Title: $title")
			appendLine()
			appendLine(report ?: "No Haxe crash report was provided.")
		}
		runCatching {
			launchCrashActivity(context, formattedReport)
		}.onFailure { handlerError ->
			Log.e(TAG, "Haxe crash recovery activity could not be launched.", handlerError)
		}
	}

	private fun launchCrashActivity(context: Context, report: String) {
		val crashFile = File(context.cacheDir, CRASH_FILE)
		crashFile.writeText(report.take(MAX_REPORT_CHARS))

		val intent = Intent(context, LimeCrashActivity::class.java)
			.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TASK)
			.putExtra(EXTRA_CRASH_FILE, crashFile.absolutePath)

		context.startActivity(intent)
	}

	private fun buildReport(context: Context, thread: Thread, throwable: Throwable): String {
		val packageInfo = runCatching {
			context.packageManager.getPackageInfo(context.packageName, 0)
		}.getOrNull()
		val appVersion = packageInfo?.versionName ?: "unknown"
		val versionCode = packageInfo?.compatLongVersionCode() ?: -1L
		val timestamp = SimpleDateFormat("yyyy-MM-dd HH:mm:ss.SSS Z", Locale.US).format(Date())

		return buildString {
			appendLine("Time: $timestamp")
			appendLine("Package: ${context.packageName}")
			appendLine("Version: $appVersion ($versionCode)")
			appendLine("Thread: ${thread.name}")
			appendLine("Device: ${Build.MANUFACTURER} ${Build.MODEL}")
			appendLine("Android: ${Build.VERSION.RELEASE} / API ${Build.VERSION.SDK_INT}")
			appendLine()
			appendLine(Log.getStackTraceString(throwable))
		}
	}

	@Suppress("DEPRECATION")
	private fun PackageInfo.compatLongVersionCode(): Long {
		return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.P) longVersionCode else versionCode.toLong()
	}
}

class LimeCrashActivity : ComponentActivity() {
	override fun onCreate(savedInstanceState: Bundle?) {
		super.onCreate(savedInstanceState)

		val crashReport = readCrashReport()
		setContent {
			LimeCrashTheme {
				CrashRecoveryScreen(
					crashReport = crashReport,
					onRestart = ::restartGame,
					onClose = ::closeRecovery
				)
			}
		}
	}

	private fun readCrashReport(): String {
		val path = intent.getStringExtra(LimeCrashHandler.EXTRA_CRASH_FILE) ?: return ""
		return runCatching { File(path).readText() }.getOrDefault("")
	}

	private fun restartGame() {
		val launchIntent = packageManager.getLaunchIntentForPackage(packageName)
		if (launchIntent != null) {
			launchIntent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TASK)
			startActivity(launchIntent)
		}

		closeRecovery()
	}

	private fun closeRecovery() {
		finishAndRemoveTask()
		Process.killProcess(Process.myPid())
		exitProcess(0)
	}
}

@Composable
private fun LimeCrashTheme(content: @Composable () -> Unit) {
	MaterialTheme(
		colorScheme = darkColorScheme(
			primary = Color(0xFFFFB15C),
			onPrimary = Color(0xFF301600),
			secondary = Color(0xFF8AD7C1),
			background = Color(0xFF101113),
			surface = Color(0xFF191B20),
			surfaceVariant = Color(0xFF22252C),
			onBackground = Color(0xFFF2F0EA),
			onSurface = Color(0xFFF2F0EA),
			onSurfaceVariant = Color(0xFFC9CDD6),
			error = Color(0xFFFFB4AB)
		),
		typography = Typography(),
		content = content
	)
}

@Composable
private fun CrashRecoveryScreen(
	crashReport: String,
	onRestart: () -> Unit,
	onClose: () -> Unit
) {
	var showDetails by remember { mutableStateOf(false) }
	val displayReport = crashReport.ifBlank {
		"No crash report was written. The app stopped before Android could save the details."
	}

	Surface(
		modifier = Modifier.fillMaxSize(),
		color = MaterialTheme.colorScheme.background
	) {
		Box(
			modifier = Modifier
				.fillMaxSize()
				.background(
					Brush.verticalGradient(
						listOf(
							Color(0xFF252024),
							Color(0xFF101113),
							Color(0xFF101113)
						)
					)
				)
				.padding(24.dp),
			contentAlignment = Alignment.Center
		) {
			Card(
				modifier = Modifier.fillMaxWidth(),
				shape = RoundedCornerShape(28.dp),
				colors = CardDefaults.cardColors(containerColor = MaterialTheme.colorScheme.surface),
				border = BorderStroke(1.dp, Color.White.copy(alpha = 0.08f)),
				elevation = CardDefaults.cardElevation(defaultElevation = 8.dp)
			) {
				Column(
					modifier = Modifier.padding(24.dp),
					verticalArrangement = Arrangement.spacedBy(18.dp)
				) {
					Row(
						horizontalArrangement = Arrangement.spacedBy(16.dp),
						verticalAlignment = Alignment.CenterVertically
					) {
						Box(
							modifier = Modifier
								.size(56.dp)
								.clip(CircleShape)
								.background(MaterialTheme.colorScheme.primary.copy(alpha = 0.18f)),
							contentAlignment = Alignment.Center
						) {
							Icon(
								imageVector = Icons.Rounded.ErrorOutline,
								contentDescription = null,
								modifier = Modifier.size(30.dp),
								tint = MaterialTheme.colorScheme.primary
							)
						}

						Column(verticalArrangement = Arrangement.spacedBy(4.dp)) {
							Text(
								text = "Plus Engine se detuvo",
								style = MaterialTheme.typography.headlineSmall,
								fontWeight = FontWeight.Bold
							)
							Text(
								text = "Puedes reabrir el juego o cerrar esta pantalla.",
								style = MaterialTheme.typography.bodyMedium,
								color = MaterialTheme.colorScheme.onSurfaceVariant
							)
						}
					}

					Row(
						modifier = Modifier.fillMaxWidth(),
						horizontalArrangement = Arrangement.spacedBy(12.dp)
					) {
						Button(
							onClick = onRestart,
							modifier = Modifier.weight(1f),
							shape = RoundedCornerShape(18.dp),
							colors = ButtonDefaults.buttonColors(containerColor = MaterialTheme.colorScheme.primary)
						) {
							Icon(Icons.Rounded.Refresh, contentDescription = null)
							Spacer(Modifier.size(8.dp))
							Text("Volver al launcher")
						}

						OutlinedButton(
							onClick = onClose,
							modifier = Modifier.weight(1f),
							shape = RoundedCornerShape(18.dp)
						) {
							Icon(Icons.Rounded.Close, contentDescription = null)
							Spacer(Modifier.size(8.dp))
							Text("Cerrar")
						}
					}

					Row(
						modifier = Modifier.fillMaxWidth(),
						verticalAlignment = Alignment.CenterVertically
					) {
						Text(
							text = "Detalles tecnicos",
							modifier = Modifier.weight(1f),
							style = MaterialTheme.typography.titleMedium,
							fontWeight = FontWeight.SemiBold
						)
						IconButton(onClick = { showDetails = !showDetails }) {
							Icon(
								imageVector = if (showDetails) Icons.Rounded.ExpandLess else Icons.Rounded.ExpandMore,
								contentDescription = if (showDetails) "Ocultar detalles" else "Ver detalles"
							)
						}
					}

					if (showDetails) {
						SelectionContainer {
							Text(
								text = displayReport,
								modifier = Modifier
									.fillMaxWidth()
									.height(220.dp)
									.clip(RoundedCornerShape(18.dp))
									.background(MaterialTheme.colorScheme.surfaceVariant)
									.verticalScroll(rememberScrollState())
									.padding(14.dp),
								style = MaterialTheme.typography.bodySmall,
								fontFamily = FontFamily.Monospace,
								color = MaterialTheme.colorScheme.onSurfaceVariant
							)
						}
					}
				}
			}
		}
	}
}
