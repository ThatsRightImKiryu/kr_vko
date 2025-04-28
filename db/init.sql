    CREATE TABLE IF NOT EXISTS system_elements (
        id SERIAL PRIMARY KEY,
        name CHAR UNIQUE
    );

    CREATE TABLE IF NOT EXISTS targets (
        id VARCHAR(100) PRIMARY KEY,
        speed REAL,
        target_type VARCHAR(100),
    );


	CREATE TABLE IF NOT EXISTS missiles (
        id SERIAL PRIMARY KEY,
        system_id INTEGER,
        ammo INTEGER,
        timestamp VARCHAR(100),
        FOREIGN KEY (system_id) REFERENCES system_elements (id)
    );

    CREATE TABLE IF NOT EXISTS detections (
        id SERIAL PRIMARY KEY,
        target_id VARCHAR(100),
        system_id INTEGER,
        x INTEGER,
        y INTEGER,
        timestamp VARCHAR(100),
        FOREIGN KEY (target_id) REFERENCES targets (id),
        FOREIGN KEY (system_id) REFERENCES system_elements (id)
    );

    CREATE TABLE IF NOT EXISTS shoots (
        id SERIAL PRIMARY KEY,
        target_id VARCHAR(100),
        system_id INTEGER,
        timestamp VARCHAR(100),
        is_hit BOOLEAN,
        FOREIGN KEY (target_id) REFERENCES targets (id),
        FOREIGN KEY (system_id) REFERENCES system_elements (id)
    );