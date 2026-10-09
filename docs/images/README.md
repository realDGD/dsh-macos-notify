# README interface images

All workspaces, session names, messages, paths and requests are fabricated demonstration data. No live user conversation, account identifier or home-directory path is included.

The unsuffixed assets are used by the Chinese README. The `-en` assets are used by the English README.

| Image | Source and scope |
| --- | --- |
| `menu-sessions.png` | Actual native menu-bar screenshot supplied and explicitly selected during review, with a clean plain backdrop. It shows activity/history, approval buttons and the complete-questionnaire entry. |
| `menu-icon-states.gif` | User-supplied recording of the isolated native preview, using the actual product icon and row components. It shows four icon states, fish rotation and vertically arranged approval buttons. The preview has no live Host connection or actionable requests. The original GIF is copied unchanged, preserving every animation frame and its timing. |
| `notification-approval.png` | Actual macOS approval notification supplied during review, with the Allow/Deny/details action menu expanded. The isolated demo request cannot execute a command or reach a live Host. |
| `approval-details.png` | Actual macOS screenshot supplied and explicitly selected during review, showing the opened native approval window with a fictitious tool request. The displayed command is never executed. |
| `notification-questionnaire.png` | Actual macOS question notification supplied during review, showing the two-question reminder and complete-questionnaire button. The isolated demo cannot submit a live Host answer. |
| `questionnaire.png` | Actual macOS screenshot supplied and explicitly selected during review, showing the native two-question form with selected options and independent text answers. No answer is submitted. |
| `menu-sessions-en.png` | User-supplied English native session-menu screenshot, with activity, recent sessions, Allow once/Reject actions and Open questions. |
| `menu-icon-states-en.gif` | User-supplied English recording of the actual fish-icon preview: Idle/Viewed, Needs input, Interrupted and Completed. Copied byte for byte, including all frames and timing. |
| `notification-approval-en.png` | User-supplied macOS notification screenshot, with English Allow once, Reject and View details actions. The macOS system controls follow the user's system language. |
| `approval-details-en.png` | User-supplied English native approval-details screenshot, with a fictional command, highlighted full tool arguments, permission settings and related-context entry. |
| `notification-questionnaire-en.png` | User-supplied English macOS notification screenshot for two questions, with the Open questions action. |
| `questionnaire-en.png` | User-supplied English native two-question form screenshot, with single-select and multi-select choices, independent custom-answer fields and one batch-submit button. |

The interface uses the dark appearance. The menu screenshot retains the actual macOS translucency; the temporary plain backdrop avoids including desktop content. Only identifying metadata from the PNG screenshots is removed. Encoded image data and color-profile chunks are preserved; no recoloring, background replacement, resizing or visual retouching is performed. The GIF is preserved byte for byte.

The notification screenshots also include macOS Notification Center controls; these are system controls, not DSH Notify controls. See [THIRD_PARTY.md](../../THIRD_PARTY.md) for branding information.

These images document the interface, not additional live notification or Host acceptance tests. The existing verification limits remain in [compatibility.md](../compatibility.md).

The initial offscreen graphics and washed-out single-window menu captures were rejected during review. Rejected drafts remain in private evidence and are not part of the documentation package. The real system notification screenshots were supplied during review after isolated demo notifications were posted. Only the demo requests were withdrawn, and the production helper resumed automatically.
