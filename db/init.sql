CREATE TABLE IF NOT EXISTS unified_system (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    entity_type TEXT NOT NULL CHECK(
        entity_type IN (
            'system_element', 
            'target', 
            'missile', 
            'detection', 
            'shoot'
        )
    ),
    
    -- Общие поля для всех объектов
    original_id TEXT,      -- Для Target (ID текстовый) и Missile
    timestamp TEXT,        -- Для Missile/Detection/Shoot
    
    -- Специфичные поля
    name TEXT,             -- Только для SystemElement (UNIQUE)
    speed REAL,            -- Только для Target
    target_type TEXT,      -- Только для Target
    ammo INTEGER,          -- Только для Missile
    x INTEGER,             -- Только для Detection
    y INTEGER,             -- Только для Detection
    is_hit BOOLEAN,        -- Только для Shoot
    
    -- Ссылочные ключи
    system_ref INTEGER,    -- Ссылка на SystemElement(id)
    target_ref INTEGER,    -- Ссылка на Target(id)
    
    -- Ограничения целостности
    FOREIGN KEY (system_ref) REFERENCES unified_system(id),
    FOREIGN KEY (target_ref) REFERENCES unified_system(id)
);

-- Частичные индексы для уникальности
CREATE UNIQUE INDEX IF NOT EXISTS idx_system_name 
ON unified_system(name) WHERE entity_type = 'system_element';

CREATE UNIQUE INDEX IF NOT EXISTS idx_target_id 
ON unified_system(original_id) WHERE entity_type = 'target';

CREATE UNIQUE INDEX IF NOT EXISTS idx_missile_id 
ON unified_system(original_id) WHERE entity_type = 'missile';
