-- Shared workspaces: directories shared among multiple users with a dedicated runner.

CREATE TABLE IF NOT EXISTS shared_workspaces (
    id TEXT PRIMARY KEY NOT NULL,
    -- Human-readable name
    name TEXT NOT NULL,
    -- URL-safe slug (lowercase, hyphens only)
    slug TEXT UNIQUE NOT NULL,
    -- Dedicated Linux user for filesystem isolation
    linux_user TEXT NOT NULL,
    -- Filesystem path (/home/oqto_shared_<slug>)
    path TEXT NOT NULL,
    -- Platform user who created this workspace
    owner_id TEXT NOT NULL REFERENCES users(id),
    -- Optional description
    description TEXT,
    -- Timestamps
    created_at TEXT NOT NULL DEFAULT (datetime('now')),
    updated_at TEXT NOT NULL DEFAULT (datetime('now'))
);

CREATE INDEX IF NOT EXISTS idx_shared_workspaces_owner ON shared_workspaces(owner_id);
CREATE INDEX IF NOT EXISTS idx_shared_workspaces_slug ON shared_workspaces(slug);

-- Membership table: which users have access to which shared workspaces.
CREATE TABLE IF NOT EXISTS shared_workspace_members (
    shared_workspace_id TEXT NOT NULL REFERENCES shared_workspaces(id) ON DELETE CASCADE,
    user_id TEXT NOT NULL REFERENCES users(id),
    -- owner: full control; admin: manage members + workdirs; member: use; viewer: read-only
    role TEXT NOT NULL DEFAULT 'member' CHECK (role IN ('owner', 'admin', 'member', 'viewer')),
    added_at TEXT NOT NULL DEFAULT (datetime('now')),
    added_by TEXT REFERENCES users(id),
    PRIMARY KEY (shared_workspace_id, user_id)
);

CREATE INDEX IF NOT EXISTS idx_shared_workspace_members_user ON shared_workspace_members(user_id);
CREATE INDEX IF NOT EXISTS idx_shared_workspace_members_workspace ON shared_workspace_members(shared_workspace_id);
