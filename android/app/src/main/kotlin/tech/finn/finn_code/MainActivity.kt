package tech.finn.finn_code

import android.os.Build
import android.os.Handler
import android.os.Looper
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.embedding.android.FlutterActivity
import io.flutter.plugin.common.MethodChannel
import java.io.File
import java.util.concurrent.Executors
import java.util.concurrent.TimeUnit

class MainActivity : FlutterActivity() {
    private val channelName = "tech.finn.finn_code/android_runtime"
    private val worker = Executors.newSingleThreadExecutor()
    private val mainHandler = Handler(Looper.getMainLooper())

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, channelName)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "runtimeInfo" -> result.success(runtimeInfo())
                    "listFiles" -> runAsync(result) {
                        listFiles(call.argument<String>("path") ?: ".")
                    }
                    "readFile" -> runAsync(result) {
                        readFile(call.argument<String>("path") ?: "")
                    }
                    "writeFile" -> runAsync(result) {
                        writeFile(
                            call.argument<String>("path") ?: "",
                            call.argument<String>("content") ?: "",
                        )
                        null
                    }
                    "deleteFile" -> runAsync(result) {
                        deleteWorkspaceFile(call.argument<String>("path") ?: "")
                        null
                    }
                    "runCommand" -> runAsync(result) {
                        runCommand(call.argument<String>("command") ?: "")
                    }
                    else -> result.notImplemented()
                }
            }
    }

    override fun onDestroy() {
        worker.shutdownNow()
        super.onDestroy()
    }

    private fun workspaceRoot(): File {
        val root = File(filesDir, "workspace")
        if (!root.exists()) root.mkdirs()
        return root
    }

    private fun runtimeInfo(): Map<String, Any?> {
        val root = workspaceRoot()
        return mapOf(
            "runtimeId" to "android-${Build.MODEL}-${Build.VERSION.SDK_INT}",
            "platform" to "Android ${Build.VERSION.RELEASE}",
            "workspaceName" to "Finn workspace",
            "workspacePath" to root.absolutePath,
            "storageBytes" to directorySize(root),
        )
    }

    private fun listFiles(path: String): List<Map<String, Any?>> {
        val target = safeWorkspaceFile(path)
        if (!target.exists() || !target.isDirectory) return emptyList()
        return target.listFiles().orEmpty()
            .sortedWith(compareByDescending<File> { it.isDirectory }.thenBy { it.name.lowercase() })
            .map { file ->
                mapOf(
                    "name" to file.name,
                    "path" to relativePath(file),
                    "isDirectory" to file.isDirectory,
                    "size" to if (file.isFile) file.length() else directorySize(file),
                    "modified" to file.lastModified(),
                )
            }
    }

    private fun readFile(path: String): String {
        val file = safeWorkspaceFile(path)
        if (!file.isFile) throw IllegalArgumentException("File not found: $path")
        if (file.length() > 512 * 1024) {
            throw IllegalArgumentException("File is too large for the mobile preview.")
        }
        return file.readText()
    }

    private fun writeFile(path: String, content: String) {
        val file = safeWorkspaceFile(path)
        file.parentFile?.mkdirs()
        file.writeText(content)
    }

    private fun deleteWorkspaceFile(path: String) {
        val file = safeWorkspaceFile(path)
        if (file == safeWorkspaceFile(".")) {
            throw IllegalArgumentException("The workspace root cannot be deleted.")
        }
        if (file.exists()) file.deleteRecursively()
    }

    private fun runCommand(command: String): Map<String, Any?> {
        val normalized = command.trim()
        val allowed = Regex(
            "^(pwd|ls|find|grep|cat|wc|du|df|date|whoami|echo)( +[A-Za-z0-9_./-]+)*$",
        ).matches(normalized)
        val arguments = normalized
            .split(Regex(" +"))
            .drop(1)
        val unsafePath = arguments.any { argument ->
            argument.startsWith("/") || argument.split('/').any { it == ".." }
        }
        if (!allowed || unsafePath) {
            throw IllegalArgumentException(
                "This mobile runtime currently allows read-only workspace commands: " +
                    "pwd, ls, find, grep, cat, wc, du, df, date, whoami, echo.",
            )
        }
        val process = ProcessBuilder("/system/bin/sh", "-c", normalized)
            .directory(workspaceRoot())
            .redirectErrorStream(true)
            .start()
        val finished = process.waitFor(15, TimeUnit.SECONDS)
        if (!finished) {
            process.destroyForcibly()
            return mapOf("exitCode" to 124, "output" to "Command timed out.")
        }
        val output = process.inputStream.bufferedReader().use { it.readText() }
        return mapOf("exitCode" to process.exitValue(), "output" to output.take(16_384))
    }

    private fun safeWorkspaceFile(relativePath: String): File {
        val root = workspaceRoot().canonicalFile
        val candidate = File(root, relativePath).canonicalFile
        val rootPrefix = root.path + File.separator
        if (candidate != root && !candidate.path.startsWith(rootPrefix)) {
            throw IllegalArgumentException("Path must stay inside the Android workspace.")
        }
        return candidate
    }

    private fun relativePath(file: File): String {
        val root = workspaceRoot().canonicalPath
        val path = file.canonicalPath
        return if (path == root) "" else path.removePrefix(root).removePrefix(File.separator)
    }

    private fun directorySize(file: File): Long {
        if (!file.exists()) return 0
        if (file.isFile) return file.length()
        return file.listFiles().orEmpty().sumOf { directorySize(it) }
    }

    private fun <T> runAsync(result: MethodChannel.Result, action: () -> T) {
        worker.execute {
            try {
                val value = action()
                mainHandler.post { result.success(value) }
            } catch (error: Throwable) {
                mainHandler.post {
                    result.error("ANDROID_RUNTIME", error.message ?: "Android runtime failed", null)
                }
            }
        }
    }
}
