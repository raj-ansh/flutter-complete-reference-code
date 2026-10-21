"""A tiny, hand-made mutation test for Pocket Organizer.

For each mutation: change one thing in the source, run the whole test suite,
and record whether any test FAILED (the mutant was "killed") or all tests still
passed (the mutant "survived"). Every file is restored afterwards.

Usage (from the project folder):  python tool/mutation_check.py
"""
import re
import subprocess
import sys
from pathlib import Path

# (id, file, text to find, replacement, what the change means)
MUTATIONS = [
    ("M1", "lib/core/list_view_model.dart",
     "    if (generation != _generation) return;",
     "    // (guard removed)",
     "a slow, old search answer may overwrite a newer one"),
    ("M2", "lib/core/calendar_date.dart",
     "    if (CalendarDate.fromDateTime(date.toLocalMidnight()) != date) {",
     "    if (false) {",
     "impossible dates such as 2026-02-30 are accepted"),
    ("M3", "lib/features/appointments/appointment.dart",
     "      startsAt.isBefore(other.endsAt) && other.startsAt.isBefore(endsAt);",
     "      !startsAt.isAfter(other.endsAt) && !other.startsAt.isAfter(endsAt);",
     "appointments that only touch count as overlapping"),
    ("M4", "lib/features/tasks/task_groups.dart",
     "  if (due.isBefore(today)) return TaskSection.overdue;",
     "  if (due.compareTo(today) <= 0) return TaskSection.overdue;",
     "a task due today is shown as overdue"),
    ("M5", "lib/features/appointments/month_grid.dart",
     "  final leading = (firstWeekday - weekStart + 7) % 7;",
     "  final leading = (firstWeekday - weekStart) % 7;",
     "the +7 is dropped from the number of blank cells"),
    ("M6", "lib/core/database.dart",
     "    await db.execute('CREATE INDEX idx_tasks_due ON tasks(due_date)');",
     "    // (index removed)",
     "the version-2 upgrade no longer creates the tasks index"),
    ("M7", "lib/features/contacts/contact_validation.dart",
     "  if (RegExp(r'[0-9]').allMatches(text).length < 3) {",
     "  if (RegExp(r'[0-9]').allMatches(text).length < 2) {",
     "a phone number needs only 2 digits instead of 3"),
    ("M8", "lib/features/contacts/contacts_view_model.dart",
     "      if (old != null && old != photoPath) await _storage.remove(old);",
     "      if (old != null && old == photoPath) await _storage.remove(old);",
     "the OLD photo is kept, and the one still in use is deleted"),
    ("M9", "lib/features/notes/notes_view_model.dart",
     "    final now = _clock.now();",
     "    final now = DateTime.now().toUtc();",
     "notes are stamped with the real clock instead of the injected one"),
    ("M10", "lib/core/list_screen_body.dart",
     "const SliverToBoxAdapter(child: SizedBox(height: 88)),",
     "const SliverToBoxAdapter(child: SizedBox(height: 0)),",
     "no room under the list for the floating button"),
    ("M11", "lib/core/state_views.dart",
     "            Icon(icon, size: 64, color: theme.colorScheme.outline),",
     "            Icon(icon, size: 24, color: theme.colorScheme.outline),",
     "the empty-state icon is much smaller"),
    ("M12", "lib/features/notes/note_edit_screen.dart",
     "      canPop: !_dirty,",
     "      canPop: true,",
     "leaving an edited note no longer asks for confirmation"),
]


def run_tests() -> tuple[str, str]:
    """Returns (verdict, first failing test). Verdicts: passed, killed,
    compile error, tool error."""
    result = subprocess.run(
        ["flutter", "test", "--reporter", "expanded"],
        capture_output=True, text=True, timeout=900, shell=sys.platform == "win32",
        encoding="utf-8", errors="replace",  # test output may contain any character
    )
    out = result.stdout + result.stderr
    if result.returncode == 0:
        return "passed", ""
    if "Compilation failed" in out or re.search(r"\.dart:\d+:\d+: Error:", out):
        return "compile error", ""
    failing = [
        line.split(": ", 2)[-1].replace("[E]", "").strip()
        for line in out.splitlines()
        if line.rstrip().endswith("[E]") and "loading " not in line
    ]
    if failing:
        return "killed", failing[0]
    return "tool error", out.strip().splitlines()[-1][:80] if out.strip() else ""


def main() -> None:
    only = set(sys.argv[1:])  # optional: ids of the mutations to run, e.g. M12
    verdict, _ = run_tests()
    print("baseline (no change):", verdict, flush=True)
    if verdict != "passed":
        sys.exit("The tests must pass before any mutation is made.")
    rows = []
    for mid, file, old, new, meaning in MUTATIONS:
        if only and mid not in only:
            continue
        path = Path(file)
        original = path.read_bytes().decode("utf-8")  # bytes: keep line endings exactly
        if original.count(old) != 1:
            rows.append((mid, "NOT APPLIED", f"text found {original.count(old)} times", meaning))
            continue
        try:
            path.write_bytes(original.replace(old, new).encode("utf-8"))
            verdict, first = run_tests()
        finally:
            path.write_bytes(original.encode("utf-8"))
        rows.append((mid, verdict, first[:90], meaning))
        print(mid, verdict, flush=True)
    print()
    print(f"{'id':5}{'result':16}{'meaning of the change':66}first failing test")
    for mid, result, first, meaning in rows:
        label = {"passed": "SURVIVED"}.get(result, result)
        print(f"{mid:5}{label:16}{meaning:66}{first}")
    killed = sum(1 for r in rows if r[1] == "killed")
    survived = sum(1 for r in rows if r[1] == "passed")
    print(f"\n{killed} killed by a failing test, {survived} survived, "
          f"{len(rows) - killed - survived} could not be judged")


if __name__ == "__main__":
    main()
