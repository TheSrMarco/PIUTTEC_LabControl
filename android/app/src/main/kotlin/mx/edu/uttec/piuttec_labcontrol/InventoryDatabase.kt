package mx.edu.uttec.piuttec_labcontrol

import android.content.ContentValues
import android.content.Context
import android.database.sqlite.SQLiteDatabase
import android.database.sqlite.SQLiteOpenHelper
import java.util.Locale

internal class InventoryDatabase private constructor(context: Context) :
    SQLiteOpenHelper(context, "labcontrol.db", null, 6) {

    companion object {
        private var instance: InventoryDatabase? = null

        @Synchronized
        fun getInstance(context: Context): InventoryDatabase =
            instance ?: InventoryDatabase(context.applicationContext).also { instance = it }
    }

    override fun onCreate(db: SQLiteDatabase) {
        db.execSQL(
            """
            CREATE TABLE equipment (
                code TEXT PRIMARY KEY NOT NULL CHECK(length(code) BETWEEN 1 AND 32),
                name TEXT NOT NULL CHECK(length(name) BETWEEN 1 AND 80),
                serial TEXT NOT NULL DEFAULT '' CHECK(length(serial) <= 64)
            )
            """.trimIndent()
        )
        addEquipmentDetails(db)
        createLoans(db)
        addLoanLifecycle(db)
        addLoanFolios(db)
        createLocalUsers(db)
    }

    override fun onConfigure(db: SQLiteDatabase) {
        db.setForeignKeyConstraintsEnabled(true)
    }

    override fun onUpgrade(db: SQLiteDatabase, oldVersion: Int, newVersion: Int) {
        if (oldVersion < 2) addEquipmentDetails(db)
        if (oldVersion < 3) createLoans(db)
        if (oldVersion < 4) addLoanLifecycle(db)
        if (oldVersion < 5) addLoanFolios(db)
        if (oldVersion < 6) createLocalUsers(db)
    }

    /** Las credenciales permanecen en esta SQLite y NO se exportan en JSON. */
    private fun createLocalUsers(db: SQLiteDatabase) {
        db.execSQL(
            """
            CREATE TABLE local_users (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                username TEXT NOT NULL UNIQUE,
                role TEXT NOT NULL CHECK(role IN ('admin', 'operator', 'viewer')),
                salt BLOB NOT NULL,
                password_hash BLOB NOT NULL,
                is_active INTEGER NOT NULL DEFAULT 1 CHECK(is_active IN (0, 1)),
                created_at INTEGER NOT NULL
            )
            """.trimIndent()
        )
    }

    private fun createLoans(db: SQLiteDatabase) {
        db.execSQL(
            """
            CREATE TABLE loans (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                equipment_code TEXT NOT NULL REFERENCES equipment(code),
                borrower TEXT NOT NULL CHECK(length(borrower) BETWEEN 1 AND 250),
                destination TEXT NOT NULL DEFAULT '' CHECK(length(destination) <= 80),
                lent_at INTEGER NOT NULL,
                returned_at INTEGER CHECK(returned_at >= lent_at)
            )
            """.trimIndent()
        )
        db.execSQL(
            "CREATE UNIQUE INDEX one_active_loan ON loans(equipment_code) WHERE returned_at IS NULL"
        )
    }

    private fun addLoanLifecycle(db: SQLiteDatabase) {
        db.execSQL("ALTER TABLE loans ADD COLUMN due_at INTEGER")
        db.execSQL(
            """
            CREATE TABLE loan_events (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                loan_id INTEGER NOT NULL REFERENCES loans(id),
                type TEXT NOT NULL CHECK(type IN ('extension', 'incident')),
                detail TEXT NOT NULL CHECK(length(detail) BETWEEN 1 AND 500),
                created_at INTEGER NOT NULL,
                old_due_at INTEGER,
                new_due_at INTEGER,
                CHECK(type != 'extension' OR new_due_at IS NOT NULL)
            )
            """.trimIndent()
        )
        db.execSQL("CREATE INDEX loan_events_by_loan ON loan_events(loan_id, id DESC)")
    }

    /**
     * v5 preserva los IDs individuales (devoluciones e incidencias).
     * Los registros antiguos usan su propio ID como folio.
     */
    private fun addLoanFolios(db: SQLiteDatabase) {
        db.execSQL("ALTER TABLE loans ADD COLUMN folio INTEGER")
        db.execSQL("UPDATE loans SET folio = id WHERE folio IS NULL")
        db.execSQL("CREATE INDEX loans_by_folio ON loans(folio, id)")
    }

    fun listLoanEvents(id: Long): List<Map<String, Any?>> =
        readableDatabase.rawQuery(
            "SELECT id, type, detail, created_at, old_due_at, new_due_at " +
                "FROM loan_events WHERE loan_id = ? ORDER BY id DESC",
            arrayOf(id.toString())
        ).use { rows ->
            buildList {
                while (rows.moveToNext()) {
                    add(mapOf(
                        "id" to rows.getLong(0),
                        "type" to rows.getString(1),
                        "detail" to rows.getString(2),
                        "createdAt" to rows.getLong(3),
                        "oldDueAt" to if (rows.isNull(4)) null else rows.getLong(4),
                        "newDueAt" to if (rows.isNull(5)) null else rows.getLong(5)
                    ))
                }
            }
        }

    fun extendLoan(id: Long, newDueAt: Long, rawReason: String) {
        val reason = rawReason.trim()
        require(reason.length in 1..500)
        val db = writableDatabase
        db.beginTransaction()
        try {
            val previous = db.rawQuery(
                "SELECT due_at FROM loans WHERE id = ? AND returned_at IS NULL",
                arrayOf(id.toString())
            ).use { rows ->
                if (!rows.moveToFirst()) throw LoanNotActive()
                if (rows.isNull(0)) null else rows.getLong(0)
            }
            val now = System.currentTimeMillis()
            require(newDueAt > now && (previous == null || newDueAt > previous))
            val update = ContentValues().apply { put("due_at", newDueAt) }
            if (db.update("loans", update, "id = ? AND returned_at IS NULL",
                    arrayOf(id.toString())) != 1) throw LoanNotActive()
            val event = ContentValues().apply {
                put("loan_id", id)
                put("type", "extension")
                put("detail", reason)
                put("created_at", now)
                if (previous == null) putNull("old_due_at") else put("old_due_at", previous)
                put("new_due_at", newDueAt)
            }
            db.insertOrThrow("loan_events", null, event)
            db.setTransactionSuccessful()
        } finally {
            db.endTransaction()
        }
    }

    fun addLoanIncident(id: Long, rawDetail: String) {
        val detail = rawDetail.trim()
        require(detail.length in 1..500)
        val db = writableDatabase
        db.beginTransaction()
        try {
            if (!db.rawQuery("SELECT 1 FROM loans WHERE id = ?",
                    arrayOf(id.toString())).use { it.moveToFirst() }) throw LoanNotFound()
            val event = ContentValues().apply {
                put("loan_id", id)
                put("type", "incident")
                put("detail", detail)
                put("created_at", System.currentTimeMillis())
            }
            db.insertOrThrow("loan_events", null, event)
            db.setTransactionSuccessful()
        } finally {
            db.endTransaction()
        }
    }

    fun listLoans(): List<Map<String, Any?>> =
        readableDatabase.rawQuery(
            """
            SELECT l.id, l.equipment_code, e.name, l.borrower, l.destination, l.lent_at, l.returned_at, l.due_at, l.folio
            FROM loans l JOIN equipment e ON e.code = l.equipment_code
            ORDER BY l.returned_at IS NOT NULL, l.id DESC
            """.trimIndent(),
            null
        ).use { rows ->
            buildList {
                while (rows.moveToNext()) {
                    add(
                        mapOf(
                            "id" to rows.getLong(0),
                            "code" to rows.getString(1),
                            "name" to rows.getString(2),
                            "borrower" to rows.getString(3),
                            "destination" to rows.getString(4),
                            "lentAt" to rows.getLong(5),
                            "returnedAt" to if (rows.isNull(6)) null else rows.getLong(6),
                            "dueAt" to if (rows.isNull(7)) null else rows.getLong(7),
                            "folio" to rows.getLong(8)
                        )
                    )
                }
            }
        }


    /** Registra todos los equipos bajo el mismo folio o no registra ninguno. */
    fun lendMany(
        rawCodes: List<String>,
        rawBorrower: String,
        rawDestination: String,
        dueAt: Long? = null
    ): Long {
        val codes = rawCodes.map { it.trim().uppercase(Locale.ROOT) }
        val borrower = rawBorrower.trim()
        val destination = rawDestination.trim()
        require(codes.size in 1..25 && codes.distinct().size == codes.size)
        require(codes.all { it.matches(Regex("[A-Z0-9][A-Z0-9_-]{0,31}")) })
        require(borrower.length in 1..250 && destination.length <= 80)
        val now = System.currentTimeMillis()
        require(dueAt == null || dueAt > now)

        val db = writableDatabase
        db.beginTransaction()
        try {
            // El folio jamás se reutiliza para una agrupación nueva, aunque
            // los IDs individuales hayan avanzado más que los últimos folios.
            val folio = db.rawQuery(
                "SELECT COALESCE(MAX(id), 0), COALESCE(MAX(folio), 0) FROM loans",
                null
            ).use { rows ->
                rows.moveToFirst()
                maxOf(rows.getLong(0), rows.getLong(1)) + 1
            }
            for (code in codes) {
                val available = db.rawQuery(
                    """
                    SELECT 1 FROM equipment WHERE code = ? AND status = 'available'
                    AND NOT EXISTS (
                        SELECT 1 FROM loans WHERE equipment_code = ?
                        AND returned_at IS NULL
                    )
                    """.trimIndent(),
                    arrayOf(code, code)
                ).use { it.moveToFirst() }
                if (!available) throw EquipmentUnavailable()

                val values = ContentValues().apply {
                    put("folio", folio)
                    put("equipment_code", code)
                    put("borrower", borrower)
                    put("destination", destination)
                    put("lent_at", now)
                    if (dueAt == null) putNull("due_at") else put("due_at", dueAt)
                }
                db.insertOrThrow("loans", null, values)
            }
            db.setTransactionSuccessful()
            return folio
        } finally {
            db.endTransaction()
        }
    }

    fun lend(code: String, rawBorrower: String, rawDestination: String, dueAt: Long? = null) {
        lendMany(listOf(code), rawBorrower, rawDestination, dueAt)
    }

    fun returnLoan(id: Long) {
        val updated = writableDatabase.compileStatement(
            "UPDATE loans SET returned_at = MAX(lent_at, ?) WHERE id = ? AND returned_at IS NULL"
        ).use { statement ->
            statement.bindLong(1, System.currentTimeMillis())
            statement.bindLong(2, id)
            statement.executeUpdateDelete()
        }
        if (updated == 0) throw LoanNotActive()
    }

    private fun addEquipmentDetails(db: SQLiteDatabase) {
        db.execSQL("ALTER TABLE equipment ADD COLUMN category TEXT NOT NULL DEFAULT ''")
        db.execSQL("ALTER TABLE equipment ADD COLUMN brand TEXT NOT NULL DEFAULT ''")
        db.execSQL("ALTER TABLE equipment ADD COLUMN model TEXT NOT NULL DEFAULT ''")
        db.execSQL(
            "ALTER TABLE equipment ADD COLUMN status TEXT NOT NULL DEFAULT 'available' " +
                "CHECK(status IN ('available', 'maintenance', 'retired'))"
        )
    }

    fun list(): List<Map<String, String>> =
        readableDatabase.rawQuery(
            "SELECT code, name, serial, category, brand, model, status, EXISTS (" +
                "SELECT 1 FROM loans WHERE equipment_code = equipment.code AND returned_at IS NULL) " +
                "FROM equipment ORDER BY name COLLATE NOCASE, code",
            null
        ).use { rows ->
            buildList {
                while (rows.moveToNext()) {
                    add(
                        mapOf(
                            "code" to rows.getString(0),
                            "name" to rows.getString(1),
                            "serial" to rows.getString(2),
                            "category" to rows.getString(3),
                            "brand" to rows.getString(4),
                            "model" to rows.getString(5),
                            "status" to rows.getString(6),
                            "onLoan" to (rows.getInt(7) == 1).toString()
                        )
                    )
                }
            }
        }

    fun save(fields: Map<String, String>, editing: Boolean) {
        val code = fields.getValue("code").trim().uppercase(Locale.ROOT)
        val name = fields.getValue("name").trim()
        val serial = fields.getValue("serial").trim()
        val category = fields.getValue("category").trim()
        val brand = fields.getValue("brand").trim()
        val model = fields.getValue("model").trim()
        val status = fields.getValue("status")

        require(code.matches(Regex("[A-Z0-9][A-Z0-9_-]{0,31}")))
        require(name.length in 1..80 && serial.length <= 64)
        require(category.length <= 60 && brand.length <= 60 && model.length <= 60)
        require(status in setOf("available", "maintenance", "retired"))

        val values = ContentValues().apply {
            put("name", name)
            put("serial", serial)
            put("category", category)
            put("brand", brand)
            put("model", model)
            put("status", status)
        }
        if (editing) {
            val editable = "code = ? AND (? = 'available' OR NOT EXISTS (" +
                "SELECT 1 FROM loans WHERE equipment_code = equipment.code AND returned_at IS NULL))"
            if (writableDatabase.update("equipment", values, editable, arrayOf(code, status)) == 0) {
                if (readableDatabase.rawQuery(
                        "SELECT 1 FROM equipment WHERE code = ?", arrayOf(code)
                    ).use { it.moveToFirst() }) throw EquipmentUnavailable()
                throw EquipmentNotFound()
            }
            return
        }
        values.put("code", code)
        val rowId = writableDatabase.insertWithOnConflict(
            "equipment", null, values, SQLiteDatabase.CONFLICT_IGNORE
        )
        if (rowId == -1L) throw DuplicateEquipmentCode()
    }
}

internal class DuplicateEquipmentCode : IllegalStateException()
internal class EquipmentNotFound : IllegalStateException()
internal class EquipmentUnavailable : IllegalStateException()
internal class LoanNotActive : IllegalStateException()
internal class LoanNotFound : IllegalStateException()
