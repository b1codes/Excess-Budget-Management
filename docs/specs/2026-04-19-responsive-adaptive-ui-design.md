# Design Spec: Responsive & Adaptive UI

**Date:** 2026-04-19
**Topic:** Implementing Responsive and Adaptive Layouts across all form factors.

## Overview
This document outlines the strategy for transforming the Excess-Budget-Management application into a truly responsive and adaptive platform. It focuses on navigation transitions, master-detail patterns, and device-specific UX enhancements.

## 1. Breakpoints & Classification
We will use standard Material 3 breakpoints to classify devices based on their logical width:

| Breakpoint | Range | Typical Device |
| :--- | :--- | :--- |
| **Compact** | < 600dp | Mobile (Portrait) |
| **Medium** | 600dp - 1200dp | Tablet, Mobile (Landscape) |
| **Expanded** | > 1200dp | Desktop, Large Tablets |

## 2. Navigation Strategy: Unified Adaptive Scaffold
The current navigation in `DashboardScreen` will be replaced with a unified adaptive wrapper.

### Compact View
*   **Navigation:** Bottom `NavigationBar`.
*   **Header:** Standard `AppBar`.

### Medium & Expanded Views
*   **Navigation:** `AppBar` with a leading menu icon.
*   **Interaction:** Tapping the menu icon opens a **Modal/Dismissible SideDrawer**.
*   **Space Management:** The drawer will overlay the content to maintain maximum focus on the dashboard/data.

## 3. Master-Detail Pattern
To utilize horizontal real estate on wider screens, a master-detail pattern will be implemented for:
*   **Accounts Feature**
*   **Goals Feature**

### Logic:
*   **Compact:** Single-pane list. Tapping an item uses `Navigator.push` to show details.
*   **Medium/Expanded:** Split-pane (1:2 ratio). The list remains on the left, and the right pane updates dynamically when an item is selected.

## 4. Feature-Specific Adaptivity
*   **Dashboard (Overview):** Transition from a single vertical list to a responsive grid of widgets.
*   **Touch Targets:** All interactive elements will be verified to have a minimum hit area of 48x48 pixels.
*   **Desktop Enhancements:** Hover effects on cards and buttons; styled scrollbars.

## 5. Success Criteria
*   App functions seamlessly in portrait and landscape on mobile/tablet.
*   Desktop view utilizes full width without excessive whitespace.
*   Navigation state is preserved when resizing the window (e.g., on Web).
