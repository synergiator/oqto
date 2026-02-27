# Shared Workspaces Design

Status: DRAFT
Date: 2026-02-27
Related: octo-pdb4, octo-t2bf, workspace-x7gm, octo-6nhg, octo-mj2r

## Overview

Shared workspaces allow multiple users to collaborate on code through a shared filesystem directory with a dedicated runner. Users can jointly send messages to sessions, with their names prepended so the agent understands it is talking to multiple people. A `USERS.md` file is automatically generated and loaded into agent context.

## Core Concepts

### Shared Workspace

A shared workspace is a directory owned by a dedicated Linux user (e.g., `oqto_shared_<name>`) that multiple platform users have access to. It acts as a container for one or more workdirs.

```
/home/oqto_shared_myteam/
  USERS.md                    # Auto-generated, lists members and roles
  .oqto/
    workspace.toml            # Workspace metadata (display_name, shared=true)
    shared.toml               # Shared workspace config (member list, permissions)
  projects/
    frontend/                 # Individual workdir
      .oqto/workspace.toml
      src/...
    backend/                  # Individual workdir
      .oqto/workspace.toml
      src/...
```

### Workdirs Inside Shared Workspaces

Each workdir within a shared workspace has the same features as regular workdirs:
- Own `.oqto/workspace.toml`
- Own sessions (stored in hstry scoped to the workdir path)
- Own file tree
- Own terminal

### USERS.md

Auto-generated at the shared workspace root. Updated whenever members change. Loaded by Pi as context. Example:

```markdown
# Team Members

This is a shared workspace. Multiple users may send messages in this session.
Messages are prefixed with the sender's name in square brackets.

## Members

| Name | Username | Role |
|------|----------|------|
| Alice Smith | alice | owner |
| Bob Jones | bob | admin |
| Charlie Brown | charlie | member |

## Conventions

- Messages from users appear as: [Alice] Can you refactor the auth module?
- When addressing a specific user's request, mention their name.
- All members can see the full conversation history.
```

### User-Prefixed Messages

When a user sends a prompt in a shared workspace session, the backend prepends their display name:

```
Original:  "Can you refactor the auth module?"
Sent to Pi: "[Alice] Can you refactor the auth module?"
```

This is transparent to the agent -- it sees bracketed names and can address users by name.

## Data Model

### Database Tables

```sql
-- Shared workspaces
CREATE TABLE IF NOT EXISTS shared_workspaces (
    id TEXT PRIMARY KEY NOT NULL,
    name TEXT NOT NULL,                      -- Human-readable name (unique)
    slug TEXT UNIQUE NOT NULL,               -- URL-safe slug (lowercase, hyphens)
    linux_user TEXT NOT NULL,                -- Linux user (oqto_shared_<slug>)
    path TEXT NOT NULL,                      -- Filesystem path (/home/oqto_shared_<slug>)
    owner_id TEXT NOT NULL REFERENCES users(id),
    description TEXT,
    created_at TEXT NOT NULL DEFAULT (datetime('now')),
    updated_at TEXT NOT NULL DEFAULT (datetime('now'))
);

-- Shared workspace members
CREATE TABLE IF NOT EXISTS shared_workspace_members (
    shared_workspace_id TEXT NOT NULL REFERENCES shared_workspaces(id) ON DELETE CASCADE,
    user_id TEXT NOT NULL REFERENCES users(id),
    role TEXT NOT NULL DEFAULT 'member' CHECK (role IN ('owner', 'admin', 'member', 'viewer')),
    added_at TEXT NOT NULL DEFAULT (datetime('now')),
    added_by TEXT REFERENCES users(id),
    PRIMARY KEY (shared_workspace_id, user_id)
);
```

### Roles

| Role | Permissions |
|------|------------|
| **owner** | Full control: manage members, delete workspace, create/delete workdirs, run sessions |
| **admin** | Manage members (except owner), create/delete workdirs, run sessions |
| **member** | Create workdirs, run sessions, send prompts |
| **viewer** | Read-only: view sessions and files, no prompting |

## Architecture

### Linux User Isolation

Each shared workspace gets a dedicated Linux user:
- Username: `oqto_shared_<slug>` (e.g., `oqto_shared_myteam`)
- Home: `/home/oqto_shared_<slug>/`
- Group: `oqto` (shared with all platform users for backend access)
- The dedicated user owns all files in the workspace
- Platform users access files through the backend/runner (not direct filesystem access)

### Runner

Each shared workspace gets its own runner process running as the dedicated Linux user. This runner:
- Owns all agent processes spawned in the workspace
- Has access to the shared filesystem
- Runs hstry scoped to the workspace
- Manages Pi sessions for all workdirs within

The backend routes commands to the shared workspace's runner based on the workspace membership check.

### Session Routing

When a user opens a session in a shared workspace:
1. Backend checks `shared_workspace_members` for access
2. Backend routes to the shared workspace's runner (not the user's personal runner)
3. The runner spawns/manages Pi as the shared Linux user
4. All users with access see the same sessions and history

### Prompt Flow (Multi-User)

```
Frontend: User "Alice" sends "Fix the login bug"
    |
    v
Backend: Check Alice is member of shared workspace
    |
    v
Backend: Prepend user name -> "[Alice] Fix the login bug"
    |
    v
Runner (shared workspace): Forward to Pi session
    |
    v
Pi: Sees "[Alice] Fix the login bug", knows Alice is asking
```

## API Endpoints

### Shared Workspace CRUD

```
POST   /api/shared-workspaces              # Create shared workspace
GET    /api/shared-workspaces              # List workspaces user has access to
GET    /api/shared-workspaces/:id          # Get workspace details
PATCH  /api/shared-workspaces/:id          # Update workspace (name, description)
DELETE /api/shared-workspaces/:id          # Delete workspace (owner only)
```

### Member Management

```
GET    /api/shared-workspaces/:id/members           # List members
POST   /api/shared-workspaces/:id/members           # Add member
PATCH  /api/shared-workspaces/:id/members/:user_id  # Update member role
DELETE /api/shared-workspaces/:id/members/:user_id  # Remove member
```

### Workdir Management (within shared workspace)

```
POST   /api/shared-workspaces/:id/workdirs          # Create workdir
GET    /api/shared-workspaces/:id/workdirs           # List workdirs
DELETE /api/shared-workspaces/:id/workdirs/:name     # Delete workdir
```

## Frontend Integration

### Sidebar

Shared workspaces appear as a separate section in the sidebar, below personal projects:

```
PROJECTS
  my-app
  my-lib

SHARED WORKSPACES
  Team Alpha          [Alice, Bob, Charlie]
    frontend
    backend
  Design System       [Alice, Dave]
    components
```

### Session View

Sessions in shared workspaces show:
- "Shared" badge on the session
- User avatars/names for who's in the session
- Each message shows the sender's name
- Permission-based action buttons (viewers can't prompt)

### Create Dialog

A "New Shared Workspace" dialog accessible from the sidebar:
- Name (required)
- Description (optional)
- Initial members (search/add users)

## Implementation Phases

### Phase 1: Backend Foundation (this PR)
- Database migration for shared_workspaces and shared_workspace_members
- Models, repository, service layer
- API endpoints for CRUD and member management
- Usermgr command for creating shared workspace Linux users
- User-prepended prompts
- USERS.md generation

### Phase 2: Runner Integration
- Shared workspace runner spawning and lifecycle
- Session routing to shared workspace runners
- hstry scoping per shared workspace

### Phase 3: Frontend
- Sidebar section for shared workspaces
- Create/manage shared workspace dialogs
- Member management UI
- Shared session indicators

## Security Considerations

- Backend always validates membership before routing to shared runner
- Shared workspace Linux user is isolated from personal users
- File operations go through the runner (no direct filesystem access)
- Viewers cannot send prompts or modify files
- Only owners can delete workspaces
- Only owners and admins can manage members
