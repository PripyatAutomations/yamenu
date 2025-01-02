drop table if exists user_sessions;
drop table if exists users;

CREATE TABLE user_sessions (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    --- Currently logged in userid
    uid INTEGER DEFAULT NULL,
    --- IP address of the device
    ip_address TEXT DEFAULT NULL,
    --- Device name (usually contains MAC and other text)
    dev_name TEXT DEFAULT NULL,
    --- This stores the hashed token for the cookie
    token TEXT DEFAULT NULL,
    login_time DATETIME DEFAULT CURRENT_TIMESTAMP,
    last_active DATETIME DEFAULT CURRENT_TIMESTAMP
);
CREATE TABLE users (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    name TEXT NOT NULL,
    pin TEXT NOT NULL
);
--- XXX: ToDo - Create a relationship between users.id and user_sessions.uid
CREATE UNIQUE INDEX idx_ip_dev_name ON user_sessions(ip_address, dev_name);
CREATE UNIQUE INDEX idx_token ON user_sessions(token);

--- Add users
--- Example:
--- INSERT INTO users (name, pin) VALUES ('eel', '4004');
