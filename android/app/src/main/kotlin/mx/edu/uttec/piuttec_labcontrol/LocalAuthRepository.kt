package mx.edu.uttec.piuttec_labcontrol

import android.content.ContentValues
import android.database.sqlite.SQLiteDatabase
import java.security.MessageDigest
import java.security.SecureRandom
import java.util.Locale
import javax.crypto.SecretKeyFactory
import javax.crypto.spec.PBEKeySpec

internal class AuthRequired : IllegalStateException()
internal class AccessDenied : IllegalStateException()
internal class LoginFailed : IllegalStateException()
internal class LoginThrottled : IllegalStateException()
internal class UserAlreadyExists : IllegalStateException()
internal class LastAdmin : IllegalStateException()
internal class SetupAlreadyComplete : IllegalStateException()

/**
 * Autenticación LOCAL al dispositivo: jamás se envían claves a un servidor.
 * La sesión vive en memoria; se exige iniciar sesión después de reiniciar el proceso.
 * Los roles se verifican en Kotlin antes de cualquier operación SQLite.
 */
internal class LocalAuthRepository(private val database: InventoryDatabase) {
    companion object {
        private const val ITERATIONS = 210_000
        private const val KEY_BITS = 256
        private val USERNAME = Regex("[a-z0-9][a-z0-9_.-]{2,31}")
        private const val MAX_FAILURES = 5
        private const val LOCKOUT_MS = 60_000L
    }

    private data class Account(val id: Long, val username: String, val role: String)
    @Volatile private var session: Account? = null
    private var failures = 0
    private var lockedUntil = 0L
    private val random = SecureRandom()

    private fun normalize(raw: String) = raw.trim().lowercase(Locale.ROOT)

    private fun validateUsername(username: String) {
        require(USERNAME.matches(username))
    }

    private fun validatePassword(password: String) {
        require(password.length in 10..128 && password.none { it == '\u0000' })
    }

    private fun digest(password: String, salt: ByteArray): ByteArray {
        val chars = password.toCharArray()
        val spec = PBEKeySpec(chars, salt, ITERATIONS, KEY_BITS)
        return try {
            SecretKeyFactory.getInstance("PBKDF2WithHmacSHA256")
                .generateSecret(spec).encoded
        } finally {
            spec.clearPassword()
            chars.fill('\u0000')
        }
    }

    private fun create(
        db: SQLiteDatabase,
        username: String,
        password: String,
        role: String
    ): Long {
        validateUsername(username)
        validatePassword(password)
        require(role in setOf("admin", "operator", "viewer"))
        if (db.rawQuery(
                "SELECT 1 FROM local_users WHERE username = ?", arrayOf(username)
            ).use { it.moveToFirst() }) throw UserAlreadyExists()
        val salt = ByteArray(16).also { random.nextBytes(it) }
        val values = ContentValues().apply {
            put("username", username)
            put("role", role)
            put("salt", salt)
            put("password_hash", digest(password, salt))
            put("is_active", 1)
            put("created_at", System.currentTimeMillis())
        }
        return db.insertOrThrow("local_users", null, values)
    }

    @Synchronized
    fun state(): Map<String, Any?> {
        val user = session
        val setup = database.readableDatabase.rawQuery(
            "SELECT 1 FROM local_users LIMIT 1", null
        ).use { !it.moveToFirst() }
        return mapOf(
            "needsSetup" to setup,
            "username" to user?.username,
            "role" to user?.role
        )
    }

    @Synchronized
    fun bootstrap(rawUsername: String, password: String): Map<String, Any?> {
        val username = normalize(rawUsername)
        val db = database.writableDatabase
        db.beginTransaction()
        try {
            if (db.rawQuery("SELECT 1 FROM local_users LIMIT 1", null)
                    .use { it.moveToFirst() }) throw SetupAlreadyComplete()
            val id = create(db, username, password, "admin")
            db.setTransactionSuccessful()
            session = Account(id, username, "admin")
        } finally {
            db.endTransaction()
        }
        return state()
    }

    @Synchronized
    fun login(rawUsername: String, password: String): Map<String, Any?> {
        val now = System.currentTimeMillis()
        if (now < lockedUntil) throw LoginThrottled()
        val username = normalize(rawUsername)
        val candidate = database.readableDatabase.rawQuery(
            "SELECT id, role, salt, password_hash, is_active FROM local_users WHERE username = ?",
            arrayOf(username)
        ).use { rows ->
            if (!rows.moveToFirst()) null else listOf(
                rows.getLong(0),
                rows.getString(1),
                rows.getBlob(2),
                rows.getBlob(3),
                rows.getInt(4)
            )
        }
        val valid = candidate != null &&
            candidate[4] == 1 &&
            MessageDigest.isEqual(digest(password, candidate[2] as ByteArray),
                candidate[3] as ByteArray)
        if (!valid) {
            failures += 1
            if (failures >= MAX_FAILURES) {
                lockedUntil = now + LOCKOUT_MS
                failures = 0
            }
            throw LoginFailed()
        }
        failures = 0
        lockedUntil = 0
        session = Account(candidate!![0] as Long, username, candidate[1] as String)
        return state()
    }

    @Synchronized fun logout() { session = null }

    @Synchronized
    fun requireRead() {
        if (session == null) throw AuthRequired()
    }

    @Synchronized
    fun requireOperator() {
        val role = session?.role ?: throw AuthRequired()
        if (role !in setOf("operator", "admin")) throw AccessDenied()
    }

    @Synchronized
    fun requireAdmin() {
        if (session == null) throw AuthRequired()
        if (session?.role != "admin") throw AccessDenied()
    }

    @Synchronized
    fun listUsers(): List<Map<String, Any>> {
        requireAdmin()
        return database.readableDatabase.rawQuery(
            "SELECT id, username, role, is_active FROM local_users ORDER BY username", null
        ).use { rows ->
            buildList {
                while (rows.moveToNext()) {
                    add(mapOf(
                        "id" to rows.getLong(0),
                        "username" to rows.getString(1),
                        "role" to rows.getString(2),
                        "active" to (rows.getInt(3) == 1)
                    ))
                }
            }
        }
    }

    @Synchronized
    fun addUser(rawUsername: String, password: String, role: String) {
        requireAdmin()
        val db = database.writableDatabase
        db.beginTransaction()
        try {
            create(db, normalize(rawUsername), password, role)
            db.setTransactionSuccessful()
        } finally {
            db.endTransaction()
        }
    }

    @Synchronized
    fun deactivate(id: Long) {
        requireAdmin()
        if (session?.id == id) throw AccessDenied()
        val db = database.writableDatabase
        db.beginTransaction()
        try {
            val role = db.rawQuery(
                "SELECT role FROM local_users WHERE id = ? AND is_active = 1",
                arrayOf(id.toString())
            ).use { rows ->
                if (!rows.moveToFirst()) throw IllegalArgumentException()
                rows.getString(0)
            }
            if (role == "admin") {
                val admins = db.rawQuery(
                    "SELECT COUNT(*) FROM local_users WHERE role = 'admin' AND is_active = 1",
                    null
                ).use { rows -> rows.moveToFirst(); rows.getLong(0) }
                if (admins <= 1) throw LastAdmin()
            }
            db.execSQL("UPDATE local_users SET is_active = 0 WHERE id = ?", arrayOf(id))
            db.setTransactionSuccessful()
        } finally {
            db.endTransaction()
        }
    }

    @Synchronized
    fun changePassword(oldPassword: String, newPassword: String) {
        val user = session ?: throw AuthRequired()
        validatePassword(newPassword)
        val db = database.writableDatabase
        db.beginTransaction()
        try {
            val matches = db.rawQuery(
                "SELECT salt, password_hash FROM local_users WHERE id = ? AND is_active = 1",
                arrayOf(user.id.toString())
            ).use { rows ->
                if (!rows.moveToFirst()) throw AuthRequired()
                MessageDigest.isEqual(digest(oldPassword, rows.getBlob(0)), rows.getBlob(1))
            }
            if (!matches) throw LoginFailed()
            val salt = ByteArray(16).also { random.nextBytes(it) }
            val values = ContentValues().apply {
                put("salt", salt)
                put("password_hash", digest(newPassword, salt))
            }
            db.update("local_users", values, "id = ?", arrayOf(user.id.toString()))
            db.setTransactionSuccessful()
        } finally {
            db.endTransaction()
        }
    }
}
