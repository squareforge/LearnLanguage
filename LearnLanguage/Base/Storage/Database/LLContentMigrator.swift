import Foundation

/// Stable resource IDs are mapped to local IDs once, without changing word IDs or user progress.
enum LLContentMigrator {
    static func version(at url: URL) throws -> String? {
        let db = try LLSQLiteConnection(url: url, readOnly: true)
        guard try db.query("SELECT name FROM sqlite_master WHERE type='table' AND name='ll_content_metadata'").count == 1 else { return nil }
        return try db.query("SELECT value FROM ll_content_metadata WHERE key='resource_version'").first?["value"]
    }

    static func migrate(local: URL, resource: URL, version: String, copiedFromResource: Bool = false, beforeCommit: () throws -> Void = {}) throws {
        let db = try LLSQLiteConnection(url: local)
        try db.execute("ATTACH DATABASE ? AS resource", arguments: [resource.absoluteString + "?mode=ro&immutable=1"])
        defer { try? db.execute("DETACH DATABASE resource") }
        try db.transaction {
            try db.execute("CREATE TABLE IF NOT EXISTS ll_content_metadata (key TEXT PRIMARY KEY, value TEXT NOT NULL)")
            try db.execute("CREATE TABLE IF NOT EXISTS ll_resource_word_lists (source_id INTEGER PRIMARY KEY, local_id INTEGER NOT NULL UNIQUE)")
            try db.execute("DELETE FROM ll_resource_word_lists WHERE NOT EXISTS(SELECT 1 FROM main.word_lists l WHERE l.id=ll_resource_word_lists.local_id)")
            if copiedFromResource {
                try db.execute("INSERT OR REPLACE INTO ll_resource_word_lists SELECT id, id FROM resource.word_lists")
            } else {
                // Bootstrap older installations using an unambiguous library name and category name.
                // User notebooks and ambiguous/custom libraries are never filled by category alone.
                try db.execute("""
                    INSERT OR IGNORE INTO ll_resource_word_lists(source_id, local_id)
                    SELECT r.id, MIN(l.id) FROM resource.word_lists r
                    JOIN resource.categories rc ON rc.id=r.category_id
                    JOIN main.categories lc ON lc.name=rc.name
                    JOIN main.word_lists l ON l.name=r.name AND l.category_id=lc.id
                    WHERE COALESCE(l.description,'') <> '__system_vocabulary_notebook__'
                    GROUP BY r.id HAVING COUNT(l.id)=1
                    """)
                try db.execute("""
                    INSERT INTO main.categories(name, description, icon, color, sort_order, created_at)
                    SELECT r.name,r.description,r.icon,r.color,r.sort_order,r.created_at FROM resource.categories r
                    WHERE NOT EXISTS(SELECT 1 FROM main.categories l WHERE l.name=r.name)
                    """)
                let missing = try db.query("""
                    SELECT r.id FROM resource.word_lists r
                    WHERE NOT EXISTS(SELECT 1 FROM ll_resource_word_lists m WHERE m.source_id=r.id)
                    ORDER BY r.id
                    """)
                for row in missing {
                    guard let id = row["id"] else { continue }
                    try db.execute("""
                        INSERT INTO main.word_lists(category_id,name,description,total_words,learned_words,is_favorite,created_at,updated_at)
                        SELECT lc.id,r.name,r.description,0,0,0,r.created_at,r.updated_at
                        FROM resource.word_lists r JOIN resource.categories rc ON rc.id=r.category_id
                        JOIN main.categories lc ON lc.name=rc.name WHERE r.id=?
                        """, arguments: [id])
                    try db.execute("INSERT INTO ll_resource_word_lists(source_id,local_id) VALUES(?,last_insert_rowid())", arguments: [id])
                }
                try db.execute("CREATE INDEX IF NOT EXISTS ll_words_list_text ON words(word_list_id,word COLLATE NOCASE)")
                try db.execute("""
                    CREATE TEMP TABLE ll_word_updates AS
                    SELECT l.id, r.translation, r.us_phonetic, r.uk_phonetic
                    FROM resource.words r JOIN ll_resource_word_lists m ON m.source_id=r.word_list_id
                    JOIN main.words l ON l.word_list_id=m.local_id AND l.word=r.word COLLATE NOCASE
                    """)
                try db.execute("CREATE INDEX ll_word_updates_id ON ll_word_updates(id)")
                try db.execute("""
                    UPDATE main.words SET (translation,us_phonetic,uk_phonetic)=(
                      SELECT CASE WHEN LENGTH(r.translation)>0 THEN r.translation ELSE words.translation END,
                             COALESCE(NULLIF(r.us_phonetic,''),words.us_phonetic),
                             COALESCE(NULLIF(r.uk_phonetic,''),words.uk_phonetic)
                      FROM ll_word_updates r WHERE words.id=r.id)
                    WHERE id IN (SELECT id FROM ll_word_updates)
                    """)
                try db.execute("DROP TABLE ll_word_updates")
                try db.execute("""
                    INSERT INTO main.words(word_list_id,word,translation,us_phonetic,uk_phonetic,created_at)
                    SELECT m.local_id,r.word,r.translation,r.us_phonetic,r.uk_phonetic,r.created_at
                    FROM resource.words r JOIN ll_resource_word_lists m ON m.source_id=r.word_list_id
                    WHERE NOT EXISTS(SELECT 1 FROM main.words l WHERE l.word_list_id=m.local_id AND l.word=r.word COLLATE NOCASE)
                    """)
                try db.execute("""
                    UPDATE main.word_lists SET total_words=(SELECT COUNT(*) FROM main.words w WHERE w.word_list_id=word_lists.id)
                    WHERE id IN (SELECT local_id FROM ll_resource_word_lists)
                    """)
                try mergeExamples(in: db)
            }
            try db.execute("INSERT OR REPLACE INTO ll_content_metadata(key,value) VALUES('resource_version',?)", arguments: [version])
            try beforeCommit()
        }
    }

    private static func mergeExamples(in db: LLSQLiteConnection) throws {
        try db.execute("""
            CREATE TABLE IF NOT EXISTS main.word_examples (
                id INTEGER PRIMARY KEY AUTOINCREMENT, word_text TEXT NOT NULL, sentence_en TEXT NOT NULL,
                sentence_cn TEXT, heat INTEGER DEFAULT 0, source TEXT, created_at REAL,
                difficulty_level INTEGER NOT NULL DEFAULT 0)
            """)
        let columns = try db.query("PRAGMA main.table_info(word_examples)")
        if !columns.contains(where: { $0["name"] == "difficulty_level" }) {
            try db.execute("ALTER TABLE main.word_examples ADD COLUMN difficulty_level INTEGER NOT NULL DEFAULT 0")
        }
        try db.execute("CREATE INDEX IF NOT EXISTS ll_examples_identity ON word_examples(word_text,sentence_en)")
        let resourceTables = try db.query("SELECT name FROM resource.sqlite_master WHERE type='table' AND name='word_examples'")
        guard !resourceTables.isEmpty else { return }
        try db.execute("""
            CREATE TEMP TABLE ll_example_updates AS
            SELECT l.id,r.sentence_cn,r.heat,r.source,r.difficulty_level
            FROM resource.word_examples r JOIN main.word_examples l
            ON l.word_text=r.word_text AND l.sentence_en=r.sentence_en
            """)
        try db.execute("CREATE INDEX ll_example_updates_id ON ll_example_updates(id)")
        try db.execute("""
            UPDATE main.word_examples SET (sentence_cn,heat,source,difficulty_level)=(
              SELECT r.sentence_cn,r.heat,r.source,r.difficulty_level
              FROM ll_example_updates r WHERE r.id=word_examples.id)
            WHERE id IN (SELECT id FROM ll_example_updates)
            """)
        try db.execute("DROP TABLE ll_example_updates")
        try db.execute("""
            INSERT INTO main.word_examples(word_text,sentence_en,sentence_cn,heat,source,created_at,difficulty_level)
            SELECT r.word_text,r.sentence_en,r.sentence_cn,r.heat,r.source,r.created_at,r.difficulty_level
            FROM resource.word_examples r WHERE NOT EXISTS(
              SELECT 1 FROM main.word_examples l WHERE l.word_text=r.word_text AND l.sentence_en=r.sentence_en)
            """)
    }
}
