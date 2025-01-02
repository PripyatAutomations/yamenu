drop table if exists user_sessions;
drop table if exists users;
drop table if exists groups;
drop table if exists group_members;

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
    
    --- User Locale
    locale TEXT DEFAULT NULL,
    --- Last login
    login_time DATETIME DEFAULT CURRENT_TIMESTAMP,
    --- Last time the user was seen
    last_active DATETIME DEFAULT CURRENT_TIMESTAMP
);
CREATE TABLE users (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    name TEXT NOT NULL,
    pin TEXT NOT NULL
);

create table groups (
   gid INTEGER PRIMARY KEY AUTOINCREMENT,
   grp_name TEXT NOT NULL
);

--- One entry per user/group pairing.
create table group_members (
   gmid INTEGER PRIMARY KEY AUTOINCREMENT,
   gid INTEGER NOT NULL,
   uid INTEGER NOT NULL
);

--- XXX: ToDo - Create a relationship between users.id and user_sessions.uid
--- Also for group_members.(gid|uid) to respective tables
CREATE UNIQUE INDEX idx_ip_dev_name ON user_sessions(ip_address, dev_name);
CREATE UNIQUE INDEX idx_token ON user_sessions(token);

--- Add users
--- Example:
INSERT INTO users (id, name, pin) VALUES (0, 'eel', '4004');
INSERT INTO users (name, pin) VALUES ('joe', '1551');

--- And some groups
INSERT INTO groups (gid, grp_name) VALUES (0, 'users');
INSERT INTO groups (gid, grp_name) VALUES (1, 'admins');
INSERT INTO groups (gid, grp_name) VALUES (2, 'radio');
INSERT INTO groups (gid, grp_name) VALUES (3, 'radio-admins');

--- Add all users to the 'users' group
INSERT INTO group_members (gid, uid)
SELECT g.gid, u.id
FROM users u
JOIN groups g ON g.grp_name = 'users';

--- Now make the first user an admin, if none exists
INSERT INTO group_members (gid, uid)
SELECT g.gid, u.id
FROM users u
JOIN groups g ON g.grp_name = 'admins'
WHERE NOT EXISTS (
    SELECT 1
    FROM group_members gm
    WHERE gm.gid = g.gid
)
ORDER BY u.id ASC
LIMIT 1;

--- and also a radio-admin!
INSERT INTO group_members (gid, uid)
SELECT g.gid, u.id
FROM users u
JOIN groups g ON g.grp_name = 'radio-admins'
WHERE NOT EXISTS (
    SELECT 1
    FROM group_members gm
    WHERE gm.gid = g.gid
)
ORDER BY u.id ASC
LIMIT 1;
