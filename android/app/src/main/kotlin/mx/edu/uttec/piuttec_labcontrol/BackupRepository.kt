package mx.edu.uttec.piuttec_labcontrol

import android.content.ContentValues
import android.database.sqlite.SQLiteDatabase
import org.json.JSONArray
import org.json.JSONObject

internal class InvalidBackup : IllegalArgumentException()
internal class DatabaseNotEmpty : IllegalStateException()

/**
 * Copia portable del inventario y sus préstamos. No copia archivos de sistema
 * de SQLite, lo que evita respaldos incompletos por WAL.
 */
internal class BackupRepository(private val helper: InventoryDatabase) {
    companion object {
        const val MAX_BYTES = 8 * 1024 * 1024
        private const val MAX_ROWS = 20000
        private const val FORMAT = "piuttec-labcontrol"
        private const val VERSION = 3
    }

    fun exportJson(): String {
        val db = helper.readableDatabase
        val equipment = JSONArray()
        val loans = JSONArray()
        val events = JSONArray()
        db.beginTransactionNonExclusive()
        try {
            db.rawQuery(
                "SELECT code, name, serial, category, brand, model, status FROM equipment ORDER BY code",
                null
            ).use { cursor ->
                while (cursor.moveToNext()) {
                    equipment.put(
                        JSONObject()
                            .put("code", cursor.getString(0))
                            .put("name", cursor.getString(1))
                            .put("serial", cursor.getString(2))
                            .put("category", cursor.getString(3))
                            .put("brand", cursor.getString(4))
                            .put("model", cursor.getString(5))
                            .put("status", cursor.getString(6))
                    )
                }
            }
            db.rawQuery(
                "SELECT id, equipment_code, borrower, destination, lent_at, returned_at, due_at, folio FROM loans ORDER BY id",
                null
            ).use { cursor ->
                while (cursor.moveToNext()) {
                    loans.put(
                        JSONObject()
                            .put("id", cursor.getLong(0))
                            .put("code", cursor.getString(1))
                            .put("borrower", cursor.getString(2))
                            .put("destination", cursor.getString(3))
                            .put("lentAt", cursor.getLong(4))
                            .put(
                                "returnedAt",
                                if (cursor.isNull(5)) JSONObject.NULL else cursor.getLong(5)
                            )
                            .put(
                                "dueAt",
                                if (cursor.isNull(6)) JSONObject.NULL else cursor.getLong(6)
                            )
                            .put("folio", cursor.getLong(7))
                    )
                }
            }
            db.rawQuery(
                "SELECT id, loan_id, type, detail, created_at, old_due_at, new_due_at " +
                    "FROM loan_events ORDER BY id",
                null
            ).use { cursor ->
                while (cursor.moveToNext()) {
                    events.put(
                        JSONObject()
                            .put("id", cursor.getLong(0))
                            .put("loanId", cursor.getLong(1))
                            .put("type", cursor.getString(2))
                            .put("detail", cursor.getString(3))
                            .put("createdAt", cursor.getLong(4))
                            .put("oldDueAt",
                                if (cursor.isNull(5)) JSONObject.NULL else cursor.getLong(5))
                            .put("newDueAt",
                                if (cursor.isNull(6)) JSONObject.NULL else cursor.getLong(6))
                    )
                }
            }
            db.setTransactionSuccessful()
        } finally {
            db.endTransaction()
        }
        val raw = JSONObject()
            .put("format", FORMAT)
            .put("version", VERSION)
            .put("exportedAt", System.currentTimeMillis())
            .put("equipment", equipment)
            .put("loans", loans)
            .put("events", events)
            .toString()
        if (raw.toByteArray(Charsets.UTF_8).size > MAX_BYTES) throw InvalidBackup()
        return raw
    }

    /** Solo importa cuando la instalación está vacía; no reemplaza ni fusiona registros. */
    fun restoreJson(raw: String): Map<String, Int> {
        if (raw.toByteArray(Charsets.UTF_8).size > MAX_BYTES) throw InvalidBackup()
        val root = try {
            JSONObject(raw)
        } catch (_: Exception) {
            throw InvalidBackup()
        }
        val version = root.optInt("version", -1)
        if (root.optString("format") != FORMAT || version !in 1..VERSION) {
            throw InvalidBackup()
        }
        val equipmentArray = root.optJSONArray("equipment") ?: throw InvalidBackup()
        val loansArray = root.optJSONArray("loans") ?: throw InvalidBackup()
        val eventsArray = if (version == 1) JSONArray()
            else root.optJSONArray("events") ?: throw InvalidBackup()
        if (equipmentArray.length() > MAX_ROWS || loansArray.length() > MAX_ROWS ||
            eventsArray.length() > MAX_ROWS) throw InvalidBackup()

        val codes = mutableSetOf<String>()
        val equipment = buildList {
            for (i in 0 until equipmentArray.length()) {
                val row = equipmentArray.optJSONObject(i) ?: throw InvalidBackup()
                val code = string(row, "code", 32, required = true)
                val name = string(row, "name", 80, required = true)
                if (!code.matches(Regex("[A-Z0-9][A-Z0-9_-]{0,31}"))
                    || !codes.add(code)) throw InvalidBackup()
                val status = string(row, "status", 20, required = true)
                if (status !in setOf("available", "maintenance", "retired")) {
                    throw InvalidBackup()
                }
                add(
                    EquipmentRow(
                        code = code,
                        name = name,
                        serial = string(row, "serial", 64),
                        category = string(row, "category", 60),
                        brand = string(row, "brand", 60),
                        model = string(row, "model", 60),
                        status = status
                    )
                )
            }
        }

        val ids = mutableSetOf<Long>()
        val activeCodes = mutableSetOf<String>()
        val folioDetails = mutableMapOf<Long, Triple<String, String, Long>>()
        val loans = buildList {
            for (i in 0 until loansArray.length()) {
                val row = loansArray.optJSONObject(i) ?: throw InvalidBackup()
                val id = positiveLong(row, "id")
                val code = string(row, "code", 32, required = true)
                val borrower = string(row, "borrower", 80, required = true)
                val destination = string(row, "destination", 80)
                val lentAt = nonNegativeLong(row, "lentAt")
                val returnedValue = row.opt("returnedAt")
                val returnedAt = if (returnedValue == null || returnedValue == JSONObject.NULL) {
                    null
                } else {
                    nonNegativeLong(row, "returnedAt")
                }
                if (!ids.add(id) || code !in codes || (returnedAt != null && returnedAt < lentAt)) {
                    throw InvalidBackup()
                }
                if (returnedAt == null && !activeCodes.add(code)) throw InvalidBackup()
                val dueValue = if (version == 1) JSONObject.NULL else row.opt("dueAt")
                val dueAt = if (dueValue == null || dueValue == JSONObject.NULL) null
                    else nonNegativeLong(row, "dueAt")
                if (dueAt != null && dueAt < lentAt) throw InvalidBackup()
                val folio = if (version < 3) id else positiveLong(row, "folio")
                val details = Triple(borrower, destination, lentAt)
                val previousDetails = folioDetails.putIfAbsent(folio, details)
                if (previousDetails != null && previousDetails != details) throw InvalidBackup()
                add(LoanRow(id, folio, code, borrower, destination, lentAt, returnedAt, dueAt))
            }
        }
        if (equipment.any { it.code in activeCodes && it.status != "available" }) {
            throw InvalidBackup()
        }

        val eventIds = mutableSetOf<Long>()
        val events = buildList {
            for (i in 0 until eventsArray.length()) {
                val row = eventsArray.optJSONObject(i) ?: throw InvalidBackup()
                val id = positiveLong(row, "id")
                val loanId = positiveLong(row, "loanId")
                val type = string(row, "type", 20, required = true)
                val detail = string(row, "detail", 500, required = true)
                val createdAt = nonNegativeLong(row, "createdAt")
                val oldDueValue = row.opt("oldDueAt")
                val newDueValue = row.opt("newDueAt")
                val oldDueAt = if (oldDueValue == null || oldDueValue == JSONObject.NULL)
                    null else nonNegativeLong(row, "oldDueAt")
                val newDueAt = if (newDueValue == null || newDueValue == JSONObject.NULL)
                    null else nonNegativeLong(row, "newDueAt")
                if (!eventIds.add(id) || loanId !in ids ||
                    type !in setOf("incident", "extension")) throw InvalidBackup()
                if (type == "incident" && (oldDueAt != null || newDueAt != null)) {
                    throw InvalidBackup()
                }
                if (type == "extension" && (newDueAt == null ||
                        (oldDueAt != null && newDueAt <= oldDueAt))) {
                    throw InvalidBackup()
                }
                add(EventRow(id, loanId, type, detail, createdAt, oldDueAt, newDueAt))
            }
        }

        val db = helper.writableDatabase
        db.beginTransaction()
        try {
            if (rowCount(db, "equipment") != 0L || rowCount(db, "loans") != 0L) {
                throw DatabaseNotEmpty()
            }

            for (item in equipment) {
                val values = ContentValues().apply {
                    put("code", item.code)
                    put("name", item.name)
                    put("serial", item.serial)
                    put("category", item.category)
                    put("brand", item.brand)
                    put("model", item.model)
                    put("status", item.status)
                }
                db.insertOrThrow("equipment", null, values)
            }
            for (item in loans) {
                val values = ContentValues().apply {
                    put("id", item.id)
                    put("folio", item.folio)
                    put("equipment_code", item.code)
                    put("borrower", item.borrower)
                    put("destination", item.destination)
                    put("lent_at", item.lentAt)
                    if (item.returnedAt == null) putNull("returned_at")
                    else put("returned_at", item.returnedAt)
                    if (item.dueAt == null) putNull("due_at")
                    else put("due_at", item.dueAt)
                }
                db.insertOrThrow("loans", null, values)
            }
            for (item in events) {
                val values = ContentValues().apply {
                    put("id", item.id)
                    put("loan_id", item.loanId)
                    put("type", item.type)
                    put("detail", item.detail)
                    put("created_at", item.createdAt)
                    if (item.oldDueAt == null) putNull("old_due_at")
                    else put("old_due_at", item.oldDueAt)
                    if (item.newDueAt == null) putNull("new_due_at")
                    else put("new_due_at", item.newDueAt)
                }
                db.insertOrThrow("loan_events", null, values)
            }
            db.setTransactionSuccessful()
        } finally {
            db.endTransaction()
        }
        return mapOf("equipment" to equipment.size, "loans" to loans.size, "events" to events.size)
    }

    private fun rowCount(db: SQLiteDatabase, table: String): Long =
        db.rawQuery("SELECT COUNT(*) FROM $table", null).use {
            if (it.moveToFirst()) it.getLong(0) else 0L
        }

    private fun string(
        source: JSONObject,
        key: String,
        max: Int,
        required: Boolean = false
    ): String {
        val value = source.opt(key)
        if (value !is String || value.length > max || (required && value.isBlank())) {
            throw InvalidBackup()
        }
        return value
    }

    private fun positiveLong(source: JSONObject, key: String): Long =
        nonNegativeLong(source, key).also { if (it == 0L) throw InvalidBackup() }

    private fun nonNegativeLong(source: JSONObject, key: String): Long {
        val number = source.opt(key)
        if (number !is Number) throw InvalidBackup()
        val result = number.toLong()
        if (result < 0 || result.toDouble() != number.toDouble()) throw InvalidBackup()
        return result
    }

    private data class EquipmentRow(
        val code: String,
        val name: String,
        val serial: String,
        val category: String,
        val brand: String,
        val model: String,
        val status: String
    )

    private data class LoanRow(
        val id: Long,
        val folio: Long,
        val code: String,
        val borrower: String,
        val destination: String,
        val lentAt: Long,
        val returnedAt: Long?,
        val dueAt: Long?
    )

    private data class EventRow(
        val id: Long,
        val loanId: Long,
        val type: String,
        val detail: String,
        val createdAt: Long,
        val oldDueAt: Long?,
        val newDueAt: Long?
    )
}
