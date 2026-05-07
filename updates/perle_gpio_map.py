# perle_gpio_map.py
import os
from typing import Dict

# -----------------------------------------------------------------------------
# Configuration Map with Unique Separators
# -----------------------------------------------------------------------------
GPIO_PINS: Dict[str, Dict[str, object]] = {
    "SEP_0": {"separator": True},
    # ---------------- CELL & SIM / INPUTS ----------------
    "SIM2_DETECT":       {"bank": 0, "line": 49, "dir": "in", "active_low": "as-is", "bias": "pull-up", "value": None},
    "SIM1_DETECT":       {"bank": 0, "line": 52, "dir": "in", "active_low": "as-is", "bias": "pull-up", "value": None},
    "SIM_SELECT1N_2":    {"bank": 0, "line": 60, "dir": "out", "active_low": "no", "bias": "pull-down", "value": 0},
    "CELL_SHUTDOWN_N":   {"bank": 0, "line": 56, "dir": "out", "active_low": "yes", "bias": "pull-up", "value": 1},
    "CELL_UNCOND_RESET": {"bank": 0, "line": 59, "dir": "out", "active_low": "no", "bias": "pull-down", "value": 0},
    "CELL_FLIGHT_MODE":  {"bank": 0, "line": 85, "dir": "out", "active_low": "no", "bias": "pull-down", "value": 0},
    "CELL_GNSS_DISABLE": {"bank": 0, "line": 86, "dir": "out", "active_low": "no", "bias": "pull-down", "value": 0},
    "SEP_1": {"separator": True},

    # ---------------- CONTROL ----------------
    "WIFI_PDN_GPIO":     {"bank": 0, "line": 14, "dir": "out", "active_low": "no", "bias": "pull-up", "value": 1},
    "VPP_LDO_EN":        {"bank": 0, "line": 33, "dir": "out", "active_low": "no", "bias": "pull-down", "value": 0},
    "PATH_THROUGH_SEL":  {"bank": 0, "line": 37, "dir": "out", "active_low": "no", "bias": "pull-down", "value": 0},
    "VSEL_SD_SWITCH":    {"bank": 0, "line": 45, "dir": "out", "active_low": "no", "bias": "pull-up", "value": 1},
    "PMIC_STBY":         {"bank": 0, "line": 51, "dir": "out", "active_low": "no", "bias": "pull-up", "value": 1},
    "SEP_2": {"separator": True},

    # ---------------- BUTTON / INPUT ----------------
    "PUSH_KEY":          {"bank": 1, "line": 36, "dir": "in", "active_low": "as-is", "bias": "pull-up", "value": None},
    "DC_VALIDN":         {"bank": 1, "line": 73, "dir": "in", "active_low": "as-is", "bias": "pull-down", "value": None},
    "POE_VALIDN":        {"bank": 1, "line": 74, "dir": "in", "active_low": "as-is", "bias": "pull-up", "value": None},
    "SEP_3": {"separator": True},

    # ---------------- UARTC0 (THVD4431) ----------------
    "UARTC0_MODE0":      {"bank": 1, "line": 46, "dir": "out", "active_low": "no", "bias": "pull-up", "value": 1},
    "UARTC0_MODE1":      {"bank": 1, "line": 42, "dir": "out", "active_low": "no", "bias": "pull-up", "value": 0},
    "UARTC0_MODE2":      {"bank": 1, "line": 43, "dir": "out", "active_low": "no", "bias": "pull-up", "value": 0},
    "UARTC0_TERM_TX":    {"bank": 1, "line": 44, "dir": "out", "active_low": "no", "bias": "pull-down", "value": 0},
    "UARTC0_TERM_RX":    {"bank": 1, "line": 45, "dir": "out", "active_low": "no", "bias": "pull-down", "value": 0},
    "UARTC0_SLR":        {"bank": 1, "line": 49, "dir": "out", "active_low": "no", "bias": "pull-up", "value": 1},
    "UARTC0_SHUT_N":     {"bank": 1, "line": 50, "dir": "out", "active_low": "yes", "bias": "pull-down", "value": 1},
    "SEP_4": {"separator": True},

    # ---------------- UARTC2 (THVD4431) ----------------
    "UARTC2_MODE0":      {"bank": 0, "line": 40, "dir": "out", "active_low": "no", "bias": "pull-up", "value": 1},
    "UARTC2_MODE1":      {"bank": 0, "line": 44, "dir": "out", "active_low": "no", "bias": "pull-up", "value": 0},
    "UARTC2_MODE2":      {"bank": 0, "line": 32, "dir": "out", "active_low": "no", "bias": "pull-up", "value": 0},
    "UARTC2_TERM_TX":    {"bank": 0, "line": 41, "dir": "out", "active_low": "no", "bias": "pull-down", "value": 0},
    "UARTC2_TERM_RX":    {"bank": 0, "line": 42, "dir": "out", "active_low": "no", "bias": "pull-down", "value": 0},
    "UARTC2_SLR":        {"bank": 0, "line": 35, "dir": "out", "active_low": "no", "bias": "pull-up", "value": 1},
    "UARTC2_SHUT_N":     {"bank": 0, "line": 36, "dir": "out", "active_low": "yes", "bias": "pull-down", "value": 1},
    "SEP_5": {"separator": True},

    # ---------------- UARTC4 (THVD4431) ----------------
    "UARTC4_MODE0":      {"bank": 1, "line": 5, "dir": "out", "active_low": "no", "bias": "pull-up", "value": 1},
    "UARTC4_MODE1":      {"bank": 1, "line": 1, "dir": "out", "active_low": "no", "bias": "pull-up", "value": 0},
    "UARTC4_MODE2":      {"bank": 1, "line": 26, "dir": "out", "active_low": "no", "bias": "pull-up", "value": 0},
    "UARTC4_TERM_TX":    {"bank": 1, "line": 41, "dir": "out", "active_low": "no", "bias": "pull-down", "value": 0},
    "UARTC4_TERM_RX":    {"bank": 1, "line": 40, "dir": "out", "active_low": "no", "bias": "pull-down", "value": 0},
    "UARTC4_SLR":        {"bank": 1, "line": 13, "dir": "out", "active_low": "no", "bias": "pull-up", "value": 1},
    "UARTC4_SHUT_N":     {"bank": 1, "line": 33, "dir": "out", "active_low": "yes", "bias": "pull-down", "value": 1},
    "SEP_6": {"separator": True},

    # ---------------- UARTC5 (THVD4431) ----------------
    "UARTC5_MODE0":      {"bank": 1, "line": 15, "dir": "out", "active_low": "no", "bias": "pull-up", "value": 1},
    "UARTC5_MODE1":      {"bank": 1, "line": 35, "dir": "out", "active_low": "no", "bias": "pull-up", "value": 0},
    "UARTC5_MODE2":      {"bank": 1, "line": 37, "dir": "out", "active_low": "no", "bias": "pull-up", "value": 0},
    "UARTC5_TERM_TX":    {"bank": 1, "line": 14, "dir": "out", "active_low": "no", "bias": "pull-down", "value": 0},
    "UARTC5_TERM_RX":    {"bank": 1, "line": 16, "dir": "out", "active_low": "no", "bias": "pull-down", "value": 0},
    "UARTC5_SLR":        {"bank": 1, "line": 30, "dir": "out", "active_low": "no", "bias": "pull-up", "value": 1},
    "UARTC5_SHUT_N":     {"bank": 1, "line": 9, "dir": "out", "active_low": "yes", "bias": "pull-down", "value": 1},
    "SEP_7": {"separator": True},
}

_RESOLVED_BANKS = {}

def list_resolved_chips():
    return sorted([os.path.join("/dev", c) for c in os.listdir("/dev") if c.startswith("gpiochip")])

def resolve_bank_path(bank: int) -> str:
    if bank in _RESOLVED_BANKS:
        return _RESOLVED_BANKS[bank]
    chips = list_resolved_chips()
    path = chips[bank + 1] if len(chips) > bank else chips[0]
    _RESOLVED_BANKS[bank] = path
    return path