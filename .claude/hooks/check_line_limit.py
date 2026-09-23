#!/usr/bin/env python3
"""PreToolUse hook: blocks Write/Edit calls that push a source file over the
configured line limit. Exit 0 = allow, exit 2 = block (stderr is fed back
to the agent as the reason)."""
import json
import os
import sys

CODE_EXTENSIONS = {
    ".py", ".js", ".jsx", ".ts", ".tsx", ".go", ".rs", ".java", ".kt",
    ".rb", ".c", ".cc", ".cpp", ".h", ".hpp", ".swift", ".cs", ".php",
    ".scala", ".vue", ".svelte",
}

DEFAULT_LIMIT = 300


def get_limit(project_root):
    limit_file = os.path.join(project_root, ".claude", "line-limit.txt")
    try:
        with open(limit_file) as f:
            return int(f.read().strip())
    except (OSError, ValueError):
        return DEFAULT_LIMIT


def main():
    payload = json.load(sys.stdin)
    tool_name = payload.get("tool_name")
    tool_input = payload.get("tool_input", {})
    project_root = payload.get("cwd") or os.getcwd()

    file_path = tool_input.get("file_path", "")
    ext = os.path.splitext(file_path)[1]
    if ext not in CODE_EXTENSIONS:
        return

    if tool_name == "Write":
        content = tool_input.get("content", "")
        line_count = content.count("\n") + 1
    elif tool_name == "Edit":
        old_string = tool_input.get("old_string", "")
        new_string = tool_input.get("new_string", "")
        replace_all = tool_input.get("replace_all", False)
        try:
            with open(file_path) as f:
                current = f.read()
        except OSError:
            return
        new_content = (
            current.replace(old_string, new_string)
            if replace_all
            else current.replace(old_string, new_string, 1)
        )
        line_count = new_content.count("\n") + 1
    else:
        return

    limit = get_limit(project_root)
    if line_count > limit:
        print(
            f"Blocked: {file_path} would be {line_count} lines, over the "
            f"{limit}-line limit (see .claude/line-limit.txt to change it). "
            f"Split this into smaller modules instead.",
            file=sys.stderr,
        )
        sys.exit(2)


if __name__ == "__main__":
    main()
