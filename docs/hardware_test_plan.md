# Physical Hardware Acceptance Test Plan

## 1. Physical Setup
- **Board**: Seeed Studio XIAO nRF52840 Sense
- **Mounting**: Dumbbell mounting strap on upper dumbbell head.
- **Initial Validation Exercise**: Controlled Bicep Curls (10 reps per set).

## 2. Test Matrix

| ID | Test Scenario | Procedure | Target Outcome | Status |
| :--- | :--- | :--- | :--- | :--- |
| **HW-01** | BLE Discovery | Power XIAO board; scan in app `/device` screen | `XIAO-Tracker` discovered via Service UUID `9f7c0001-...` within 10s | Pending Hardware |
| **HW-02** | 50 Hz Motion Streaming | Connect device and navigate to `/motion` | Observed sample rate counter displays $\approx 50\text{ Hz}$ without packet drops | Pending Hardware |
| **HW-03** | Dumbbell Curl Set (10 Reps) | Mount board to 10kg dumbbell; execute 10 controlled curls | Firmware cumulative count reaches 10 ($\pm 1$ rep target) | Pending Hardware |
| **HW-04** | Disconnect Reconciliation | Disconnect BLE mid-set for 15 seconds; reconnect | App recovers set state and reconciles cumulative rep count | Pending Hardware |
| **HW-05** | Board Reset Mid-Set | Power cycle XIAO board during active set | App flags boot change, preserves last checkpoint, requests user confirmation | Pending Hardware |
