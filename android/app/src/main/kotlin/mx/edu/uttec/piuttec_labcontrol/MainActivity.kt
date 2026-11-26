package mx.edu.uttec.piuttec_labcontrol

import android.app.Activity
import android.content.ActivityNotFoundException
import android.net.Uri
import java.io.ByteArrayOutputStream
import java.io.IOException
import java.io.InputStream
import android.content.Intent
import android.content.pm.PackageManager
import android.database.SQLException
import android.graphics.Bitmap
import android.util.Log
import com.google.zxing.BarcodeFormat
import com.google.zxing.WriterException
import com.journeyapps.barcodescanner.BarcodeEncoder
import com.journeyapps.barcodescanner.ScanContract
import com.journeyapps.barcodescanner.ScanOptions
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.StandardMethodCodec

class MainActivity : FlutterActivity() {
    private var authChannel: MethodChannel? = null
    private var localAuth: LocalAuthRepository? = null
    private var inventoryChannel: MethodChannel? = null
    private var qrChannel: MethodChannel? = null
    private var backupChannel: MethodChannel? = null
    private var pendingBackup: MethodChannel.Result? = null
    private var pendingBackupJson: String? = null
    private val scanContract = ScanContract()
    private var pendingScan: MethodChannel.Result? = null

    private companion object {
        const val EQUIPMENT_QR_REQUEST = 28173
        const val BACKUP_EXPORT_REQUEST = 28174
        const val BACKUP_RESTORE_REQUEST = 28175
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        val database = InventoryDatabase.getInstance(applicationContext)
        val messenger = flutterEngine.dartExecutor.binaryMessenger
        val backupRepository = BackupRepository(database)
        val auth = LocalAuthRepository(database)
        localAuth = auth
        authChannel = MethodChannel(
            messenger,
            "mx.edu.uttec.labcontrol/auth",
            StandardMethodCodec.INSTANCE,
            messenger.makeBackgroundTaskQueue()
        ).also { channel ->
            channel.setMethodCallHandler { call, result ->
                try {
                    when (call.method) {
                        "getState" -> result.success(auth.state())
                        "bootstrapAdmin" -> result.success(auth.bootstrap(
                            requireNotNull(call.argument<String>("username")),
                            requireNotNull(call.argument<String>("password"))
                        ))
                        "login" -> result.success(auth.login(
                            requireNotNull(call.argument<String>("username")),
                            requireNotNull(call.argument<String>("password"))
                        ))
                        "logout" -> {
                            auth.logout()
                            result.success(null)
                        }
                        "listUsers" -> result.success(auth.listUsers())
                        "createUser" -> {
                            auth.addUser(
                                requireNotNull(call.argument<String>("username")),
                                requireNotNull(call.argument<String>("password")),
                                requireNotNull(call.argument<String>("role"))
                            )
                            result.success(null)
                        }
                        "deactivateUser" -> {
                            auth.deactivate(requireNotNull(call.argument<Number>("id")).toLong())
                            result.success(null)
                        }
                        "changePassword" -> {
                            auth.changePassword(
                                requireNotNull(call.argument<String>("oldPassword")),
                                requireNotNull(call.argument<String>("newPassword"))
                            )
                            result.success(null)
                        }
                        else -> result.notImplemented()
                    }
                } catch (_: AuthRequired) {
                    result.error("auth_required", null, null)
                } catch (_: AccessDenied) {
                    result.error("access_denied", null, null)
                } catch (_: LoginFailed) {
                    result.error("invalid_login", null, null)
                } catch (_: LoginThrottled) {
                    result.error("too_many_attempts", null, null)
                } catch (_: UserAlreadyExists) {
                    result.error("duplicate_username", null, null)
                } catch (_: LastAdmin) {
                    result.error("last_admin", null, null)
                } catch (_: SetupAlreadyComplete) {
                    result.error("already_initialized", null, null)
                } catch (_: IllegalArgumentException) {
                    result.error("invalid_user", null, null)
                } catch (error: Exception) {
                    Log.e("LabControl", "Auth operation failed", error)
                    result.error("auth_failed", null, null)
                }
            }
        }
        backupChannel = MethodChannel(messenger, "mx.edu.uttec.labcontrol/backup").also {
            it.setMethodCallHandler { call, result ->
                if (!requireBackupAdmin(result)) return@setMethodCallHandler
                when (call.method) {
                    "exportBackup" -> startBackupExport(backupRepository, result)
                    "restoreBackup" -> startBackupRestore(result)
                    else -> result.notImplemented()
                }
            }
        }
        qrChannel = MethodChannel(messenger, "mx.edu.uttec.labcontrol/equipment_qr")
            .also { qr ->
                qr.setMethodCallHandler { call, result ->
                    try {
                        auth.requireRead()
                    } catch (_: AuthRequired) {
                        result.error("auth_required", null, null)
                        return@setMethodCallHandler
                    }
                    when (call.method) {
                        "render" -> renderQr(call.arguments as? String, result)
                        "scan" -> scanQr(result)
                        else -> result.notImplemented()
                    }
                }
            }
        val channel = MethodChannel(
            messenger,
            "mx.edu.uttec.labcontrol/inventory",
            StandardMethodCodec.INSTANCE,
            messenger.makeBackgroundTaskQueue()
        )
        inventoryChannel = channel
        channel.setMethodCallHandler { call, result ->
            try {
                when (call.method) {
                    "list", "listLoans", "listLoanEvents" -> auth.requireRead()
                    "add", "update" -> auth.requireAdmin()
                    "lend", "lendMany", "returnLoan", "extendLoan", "addLoanIncident" ->
                        auth.requireOperator()
                }
                when (call.method) {
                    "list" -> result.success(database.list())
                    "listLoans" -> result.success(database.listLoans())
                    "listLoanEvents" -> result.success(
                        database.listLoanEvents(
                            requireNotNull(call.argument<Number>("id")).toLong()
                        )
                    )
                    "extendLoan" -> {
                        database.extendLoan(
                            requireNotNull(call.argument<Number>("id")).toLong(),
                            requireNotNull(call.argument<Number>("dueAt")).toLong(),
                            requireNotNull(call.argument<String>("reason"))
                        )
                        result.success(null)
                    }
                    "addLoanIncident" -> {
                        database.addLoanIncident(
                            requireNotNull(call.argument<Number>("id")).toLong(),
                            requireNotNull(call.argument<String>("detail"))
                        )
                        result.success(null)
                    }
                    "lendMany" -> {
                        val folio = database.lendMany(
                            requireNotNull(call.argument<List<String>>("codes")),
                            requireNotNull(call.argument<String>("borrower")),
                            call.argument<String>("destination").orEmpty(),
                            call.argument<Number>("dueAt")?.toLong()
                        )
                        result.success(folio)
                    }
                    "lend" -> {
                        database.lend(
                            requireNotNull(call.argument<String>("code")),
                            requireNotNull(call.argument<String>("borrower")),
                            call.argument<String>("destination").orEmpty(),
                            call.argument<Number>("dueAt")?.toLong()
                        )
                        result.success(null)
                    }
                    "returnLoan" -> {
                        database.returnLoan(requireNotNull(call.argument<Number>("id")).toLong())
                        result.success(null)
                    }
                    "add", "update" -> {
                        database.save(
                            mapOf(
                                "code" to requireNotNull(call.argument<String>("code")),
                                "name" to requireNotNull(call.argument<String>("name")),
                                "serial" to call.argument<String>("serial").orEmpty(),
                                "category" to call.argument<String>("category").orEmpty(),
                                "brand" to call.argument<String>("brand").orEmpty(),
                                "model" to call.argument<String>("model").orEmpty(),
                                "status" to (call.argument<String>("status") ?: "available")
                            ),
                            editing = call.method == "update"
                        )
                        result.success(null)
                    }
                    else -> result.notImplemented()
                }
            } catch (_: AuthRequired) {
                result.error("auth_required", null, null)
            } catch (_: AccessDenied) {
                result.error("access_denied", null, null)
            } catch (_: DuplicateEquipmentCode) {
                result.error("duplicate_code", null, null)
            } catch (_: EquipmentNotFound) {
                result.error("equipment_not_found", null, null)
            } catch (_: EquipmentUnavailable) {
                result.error("equipment_unavailable", null, null)
            } catch (_: LoanNotActive) {
                result.error("loan_not_active", null, null)
            } catch (_: LoanNotFound) {
                result.error("loan_not_found", null, null)
            } catch (_: IllegalArgumentException) {
                result.error("invalid_equipment", null, null)
            } catch (error: SQLException) {
                Log.e("LabControl", "Inventory database operation failed", error)
                result.error("database_error", null, null)
            }
        }
    }

    private fun requireBackupAdmin(result: MethodChannel.Result): Boolean {
        return try {
            localAuth?.requireAdmin() ?: throw AuthRequired()
            true
        } catch (_: AuthRequired) {
            result.error("auth_required", null, null)
            false
        } catch (_: AccessDenied) {
            result.error("access_denied", null, null)
            false
        }
    }

    private fun renderQr(payload: String?, result: MethodChannel.Result) {
        if (payload.isNullOrEmpty() || payload.length > 64) {
            result.error("invalid_qr", null, null)
            return
        }
        try {
            val bitmap = BarcodeEncoder().encodeBitmap(payload, BarcodeFormat.QR_CODE, 384, 384)
            try {
                val bytes = ByteArrayOutputStream()
                if (bitmap.compress(Bitmap.CompressFormat.PNG, 100, bytes)) {
                    result.success(bytes.toByteArray())
                } else {
                    result.error("qr_render_failed", null, null)
                }
            } finally {
                bitmap.recycle()
            }
        } catch (_: WriterException) {
            result.error("qr_render_failed", null, null)
        }
    }

    @Suppress("DEPRECATION")
    private fun scanQr(result: MethodChannel.Result) {
        if (pendingScan != null) {
            result.error("scan_in_progress", null, null)
            return
        }
        if (!packageManager.hasSystemFeature(PackageManager.FEATURE_CAMERA_ANY)) {
            result.error("camera_unavailable", null, null)
            return
        }
        val options = ScanOptions()
            .setDesiredBarcodeFormats(ScanOptions.QR_CODE)
            .setPrompt("Escanea el QR del equipo")
            .setBeepEnabled(false)
            .setOrientationLocked(false)
        pendingScan = result
        try {
            startActivityForResult(scanContract.createIntent(this, options), EQUIPMENT_QR_REQUEST)
        } catch (_: ActivityNotFoundException) {
            pendingScan = null
            result.error("camera_unavailable", null, null)
        }
    }

    private fun startBackupExport(repository: BackupRepository, result: MethodChannel.Result) {
        if (pendingBackup != null) {
            result.error("operation_in_progress", null, null)
            return
        }
        pendingBackup = result
        Thread {
            try {
                val json = repository.exportJson()
                runOnUiThread {
                    if (pendingBackup !== result) return@runOnUiThread
                    pendingBackupJson = json
                    try {
                        val chooser = Intent(Intent.ACTION_CREATE_DOCUMENT)
                            .addCategory(Intent.CATEGORY_OPENABLE)
                            .setType("application/json")
                            .putExtra(
                                Intent.EXTRA_TITLE,
                                "labcontrol_backup_" + System.currentTimeMillis() + ".json"
                            )
                        @Suppress("DEPRECATION")
                        startActivityForResult(chooser, BACKUP_EXPORT_REQUEST)
                    } catch (_: ActivityNotFoundException) {
                        finishBackupError(result, "file_picker_unavailable")
                    }
                }
            } catch (_: InvalidBackup) {
                runOnUiThread { finishBackupError(result, "backup_too_large") }
            } catch (error: Exception) {
                Log.e("LabControl", "Backup export failed", error)
                runOnUiThread { finishBackupError(result, "backup_failed") }
            }
        }.start()
    }

    private fun startBackupRestore(result: MethodChannel.Result) {
        if (pendingBackup != null) {
            result.error("operation_in_progress", null, null)
            return
        }
        pendingBackup = result
        try {
            val chooser = Intent(Intent.ACTION_OPEN_DOCUMENT)
                .addCategory(Intent.CATEGORY_OPENABLE)
                .setType("application/json")
            @Suppress("DEPRECATION")
            startActivityForResult(chooser, BACKUP_RESTORE_REQUEST)
        } catch (_: ActivityNotFoundException) {
            finishBackupError(result, "file_picker_unavailable")
        }
    }

    private fun requireBackupAdminPending(result: MethodChannel.Result): Boolean {
        return try {
            localAuth?.requireAdmin() ?: throw AuthRequired()
            true
        } catch (_: AuthRequired) {
            finishBackupError(result, "auth_required")
            false
        } catch (_: AccessDenied) {
            finishBackupError(result, "access_denied")
            false
        }
    }

    private fun finishBackupError(result: MethodChannel.Result, code: String) {
        if (pendingBackup !== result) return
        pendingBackup = null
        pendingBackupJson = null
        result.error(code, null, null)
    }

    private fun finishBackupSuccess(result: MethodChannel.Result, value: Any?) {
        if (pendingBackup !== result) return
        pendingBackup = null
        pendingBackupJson = null
        result.success(value)
    }

    private fun readLimited(uri: Uri): String {
        val input: InputStream = contentResolver.openInputStream(uri)
            ?: throw IOException("Cannot open backup")
        return input.use { stream ->
            val output = ByteArrayOutputStream()
            val buffer = ByteArray(8192)
            while (true) {
                val read = stream.read(buffer)
                if (read < 0) break
                if (output.size() + read > BackupRepository.MAX_BYTES) throw InvalidBackup()
                output.write(buffer, 0, read)
            }
            String(output.toByteArray(), Charsets.UTF_8)
        }
    }

    @Suppress("DEPRECATION")
    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        if (requestCode == EQUIPMENT_QR_REQUEST) {
            val result = pendingScan
            pendingScan = null
            result?.success(scanContract.parseResult(resultCode, data).contents)
            return
        }
        if (requestCode == BACKUP_EXPORT_REQUEST || requestCode == BACKUP_RESTORE_REQUEST) {
            val result = pendingBackup ?: return
            if (!requireBackupAdminPending(result)) return
            val uri = data?.data
            if (resultCode != Activity.RESULT_OK || uri == null) {
                finishBackupSuccess(result, null)
                return
            }
            if (requestCode == BACKUP_EXPORT_REQUEST) {
                val json = pendingBackupJson ?: run {
                    finishBackupError(result, "backup_failed")
                    return
                }
                Thread {
                    try {
                        localAuth?.requireAdmin() ?: throw AuthRequired()
                        val output = contentResolver.openOutputStream(uri)
                            ?: throw IOException("Cannot write backup")
                        output.use { it.write(json.toByteArray(Charsets.UTF_8)) }
                        runOnUiThread { finishBackupSuccess(result, true) }
                    } catch (error: Exception) {
                        Log.e("LabControl", "Cannot write backup file", error)
                        runOnUiThread { finishBackupError(result, "backup_failed") }
                    }
                }.start()
            } else {
                Thread {
                    try {
                        localAuth?.requireAdmin() ?: throw AuthRequired()
                        val json = readLimited(uri)
                        val restored = BackupRepository(
                            InventoryDatabase.getInstance(applicationContext)
                        ).restoreJson(json)
                        runOnUiThread { finishBackupSuccess(result, restored) }
                    } catch (_: DatabaseNotEmpty) {
                        runOnUiThread { finishBackupError(result, "device_not_empty") }
                    } catch (_: InvalidBackup) {
                        runOnUiThread { finishBackupError(result, "invalid_backup") }
                    } catch (_: IllegalArgumentException) {
                        runOnUiThread { finishBackupError(result, "invalid_backup") }
                    } catch (error: Exception) {
                        Log.e("LabControl", "Backup restoration failed", error)
                        runOnUiThread { finishBackupError(result, "backup_failed") }
                    }
                }.start()
            }
            return
        }
        super.onActivityResult(requestCode, resultCode, data)
    }

    override fun cleanUpFlutterEngine(flutterEngine: FlutterEngine) {
        backupChannel?.setMethodCallHandler(null)
        backupChannel = null
        pendingBackup?.success(null)
        pendingBackup = null
        pendingBackupJson = null
        qrChannel?.setMethodCallHandler(null)
        qrChannel = null
        pendingScan?.success(null)
        pendingScan = null
        inventoryChannel?.setMethodCallHandler(null)
        inventoryChannel = null
        authChannel?.setMethodCallHandler(null)
        authChannel = null
        localAuth?.logout()
        localAuth = null
        super.cleanUpFlutterEngine(flutterEngine)
    }
}
