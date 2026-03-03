//! USERS.md generation for shared workspace workdirs.
//!
//! Generates a USERS.md document placed in each workdir so the agent knows
//! team members. Loaded by the custom-context-files Pi extension via
//! .pi/context.json in each workdir.

use super::models::SharedWorkspaceMemberInfo;

/// Generate USERS.md content for a shared workspace workdir.
pub fn generate_users_md(workspace_name: &str, members: &[SharedWorkspaceMemberInfo]) -> String {
    let mut md = String::new();

    md.push_str(&format!("# {} - Team\n\n", workspace_name));
    md.push_str("This is a shared workspace. Multiple users collaborate here.\n");
    md.push_str("Messages are prefixed with the sender's name in square brackets, e.g. `[Alice] hello`.\n\n");

    md.push_str("| Name | Role |\n");
    md.push_str("|------|------|\n");

    for member in members {
        md.push_str(&format!(
            "| {} | {} |\n",
            member.display_name, member.role
        ));
    }

    md.push_str("\n- Address users by name when responding to their specific requests.\n");
    md.push_str("- All members can see the full conversation history.\n");
    md.push_str("- If users give conflicting instructions, ask for clarification.\n");

    md
}

/// Generate .pi/context.json content that tells the custom-context-files
/// extension to load USERS.md.
pub fn generate_context_json() -> String {
    serde_json::json!({
        "contextFiles": [
            {
                "names": ["USERS.md"],
                "optional": false
            }
        ]
    })
    .to_string()
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::shared_workspace::models::MemberRole;

    #[test]
    fn test_generate_users_md() {
        let members = vec![
            SharedWorkspaceMemberInfo {
                user_id: "u1".to_string(),
                username: "alice".to_string(),
                display_name: "Alice Smith".to_string(),
                avatar_url: None,
                role: MemberRole::Owner,
                added_at: "2026-01-01".to_string(),
            },
            SharedWorkspaceMemberInfo {
                user_id: "u2".to_string(),
                username: "bob".to_string(),
                display_name: "Bob Jones".to_string(),
                avatar_url: None,
                role: MemberRole::Member,
                added_at: "2026-01-02".to_string(),
            },
        ];

        let md = generate_users_md("Team Alpha", &members);

        assert!(md.contains("# Team Alpha - Team"));
        assert!(md.contains("| Alice Smith | owner |"));
        assert!(md.contains("| Bob Jones | member |"));
        assert!(md.contains("conflicting instructions"));
    }

    #[test]
    fn test_generate_context_json() {
        let json = generate_context_json();
        let parsed: serde_json::Value = serde_json::from_str(&json).unwrap();
        assert_eq!(parsed["contextFiles"][0]["names"][0], "USERS.md");
        assert_eq!(parsed["contextFiles"][0]["optional"], false);
    }
}
