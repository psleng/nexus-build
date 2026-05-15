#!/usr/bin/env python3
import sys
import time
from typing import Dict, List, Optional
import gpiod
from gpiod.line import Direction, Value
from perle_gpio_map import GPIO_PINS, resolve_bank_path, list_resolved_chips

# --- THVD4431 Truth Table Logic ---
# Logic: M1=MODE1, M0=MODE0, TM=Termination(TX/RX), SLR=Slew Rate Enable
PROTOCOLS = {
    "isolate":    {"M2": 0, "M1": 0, "M0": 0, "SHUT": 0},
    "rs232":      {"M2": 0, "M1": 0, "M0": 1, "SHUT": 1},
    "rs485h":     {"M2": 0, "M1": 1, "M0": 0, "SHUT": 1},
    "rs485f":     {"M2": 0, "M1": 1, "M0": 1, "SHUT": 1},
    "rs422":      {"M2": 0, "M1": 1, "M0": 1, "SHUT": 1},
}

def get_line_settings(**kwargs):
    try:
        return gpiod.LineSettings(**kwargs)
    except AttributeError:
        return gpiod.line.LineSettings(**kwargs)

def parse_value(v_str: str) -> Value:
    v = str(v_str).upper()
    if v in ("1", "HIGH", "ACTIVE", "ON"): return Value.ACTIVE
    return Value.INACTIVE

# --- Core Protocol Feature ---
def set_protocol(uart_prefix: str, proto_name: str, extra_val: Optional[str] = None) -> int:
    proto = PROTOCOLS.get(proto_name.lower())
    if not proto:
        print(f"Error: Unknown protocol '{proto_name}'. Options: {list(PROTOCOLS.keys())}")
        return 1

    # Default logic: SLR defaults to 1 (Fast), TERM defaults to 0 (Off)
    slr_val = 1
    term_val = 0

    # Parse optional parameters based on protocol type
    if proto_name.lower() == "rs232":
        if extra_val is not None:
            slr_val = 1 if parse_value(extra_val) == Value.ACTIVE else 0
    elif proto_name.lower() in ("rs485h", "rs485f", "rs422"):
        if extra_val is not None:
            term_val = 1 if parse_value(extra_val) == Value.ACTIVE else 0

    # Map generic protocol states to hardware-specific keys
    target_states = {
        f"{uart_prefix}_MODE2":   proto["M2"],
        f"{uart_prefix}_MODE1":   proto["M1"],
        f"{uart_prefix}_MODE0":   proto["M0"],
        f"{uart_prefix}_TERM_TX": term_val,
        f"{uart_prefix}_TERM_RX": term_val,
        f"{uart_prefix}_SLR":     slr_val,
        f"{uart_prefix}_SHUT_N":  proto["SHUT"],
    }

    # Group updates by GPIO bank for atomic (batched) request
    bank_groups = {}
    for name, val in target_states.items():
        cfg = GPIO_PINS.get(name)
        if not cfg or "bank" not in cfg: continue
        path = resolve_bank_path(cfg["bank"])
        bank_groups.setdefault(path, {})[cfg["line"]] = val

    try:
        for path, lines in bank_groups.items():
            l_configs = {
                line: get_line_settings(direction=Direction.OUTPUT, 
                                        output_value=Value.ACTIVE if v else Value.INACTIVE)
                for line, v in lines.items()
            }
            # The 'with' context ensures pins are requested and then released for system use
            with gpiod.request_lines(path, consumer="perle_gpioctl/proto", config=l_configs):
                pass 

        status_msg = f"SUCCESS: {uart_prefix} configured for {proto_name.upper()}"
        if proto_name.lower() == "rs232":
            status_msg += f" (SLR={'ON' if slr_val else 'OFF'})"
        else:
            status_msg += f" (TERM={'ON' if term_val else 'OFF'})"
        print(status_msg)
        return 0
    except Exception as e:
        print(f"Error applying protocol to {uart_prefix}: {e}")
        return 1

def get_all() -> int:
    real_pins = {n: cfg for n, cfg in GPIO_PINS.items() if "bank" in cfg}
    if not real_pins: return 0
    name_width = max(len(n) for n in real_pins)
    
    chip_map = {}
    for name, cfg in real_pins.items():
        path = resolve_bank_path(cfg["bank"])
        chip_map.setdefault(path, []).append(cfg["line"])

    active_reqs = {}
    try:
        for path, lines in chip_map.items():
            settings = {l: get_line_settings(direction=Direction.AS_IS) for l in lines}
            active_reqs[path] = gpiod.request_lines(path, consumer="perle_gpioctl/get-all", config=settings)

        for name, cfg in GPIO_PINS.items():
            if "separator" in cfg:
                print("-" * 84); continue
            
            path = resolve_bank_path(cfg["bank"])
            v = active_reqs[path].get_value(cfg["line"])
            state = 'HIGH' if v == Value.ACTIVE else 'LOW'
            direction = cfg.get("dir", "???").upper()
            
            # Print with direction column added
            print(f"{name:<{name_width}}  {path} line {cfg['line']:>2}  [{direction:<3}]  {state}")
    finally:
        for r in active_reqs.values(): r.release()
    return 0

def get_gpio(name: str) -> int:
    cfg = GPIO_PINS.get(name)
    if not cfg or "bank" not in cfg: return 1
    path = resolve_bank_path(cfg["bank"])
    with gpiod.request_lines(path, consumer="perle_gpioctl/get", 
                             config={cfg["line"]: get_line_settings(direction=Direction.AS_IS)}) as req:
        val = req.get_value(cfg["line"])
        print(f"{name} = {'HIGH' if val == Value.ACTIVE else 'LOW'}")
    return 0

def set_gpio(name: str, val_str: str) -> int:
    cfg = GPIO_PINS.get(name)
    if not cfg or "bank" not in cfg:
        print(f"Error: GPIO '{name}' not found.")
        return 1
    
    path = resolve_bank_path(cfg["bank"])
    v = parse_value(val_str)
    
    with gpiod.request_lines(path, consumer="perle_gpioctl/set",
                             config={cfg["line"]: get_line_settings(direction=Direction.OUTPUT, output_value=v)}) as req:
        pass
    
    # Added confirmation message
    print(f"SET {name} to {'HIGH' if v == Value.ACTIVE else 'LOW'}")
    return 0

def apply_defaults(target: str, hold_seconds: Optional[float] = None) -> int:
    to_proc = GPIO_PINS if target == "all" else {target: GPIO_PINS.get(target)}
    chip_groups = {}
    for name, cfg in to_proc.items():
        if not cfg or "bank" not in cfg: continue
        path = resolve_bank_path(cfg["bank"])
        chip_groups.setdefault(path, []).append(cfg)

    reqs = []
    try:
        for path, pins in chip_groups.items():
            l_configs = {c["line"]: get_line_settings(
                direction=Direction.OUTPUT if c["dir"] == "out" else Direction.INPUT,
                output_value=parse_value(str(c.get("value", 0)))
            ) for c in pins}
            reqs.append(gpiod.request_lines(path, consumer="perle_gpioctl/init", config=l_configs))
        
        print(f"Defaults applied to {target}")
        if hold_seconds is not None:
            if hold_seconds < 0:
                print("Holding indefinitely... (Ctrl+C to release)"); 
                while True: time.sleep(1)
            else:
                print(f"Holding for {hold_seconds}s..."); time.sleep(hold_seconds)
    except KeyboardInterrupt: pass
    finally:
        for r in reqs: r.release()
    return 0

def print_usage():
    print("Usage: perle_gpioctl.py <command> [args]")
    print("\nCommands:")
    print("  list / get-all                  List all GPIO states & directions")
    print("  get <NAME>                      Get physical value")
    print("  set <NAME> <0|1|LOW|HIGH>       Set physical value and show confirmation")
    print("  info <NAME> / info-all          Show hardware details")
    print("  chips                           List detected chips")
    print("  apply-defaults [all|NAME]       Apply map defaults [--hold | --for <sec>]")
    print("  proto <UART> <PROTO> [val]      Set THVD4431 protocol")
    print("      UART: UARTC0, UARTC2, UARTC4, UARTC5")
    print("      PROTO: isolate, rs232, rs485h, rs422, rs485f")
    print("      [val]: For rs232, this sets SLR (0 or 1). Default 1.")
    print("             For rs485/rs422, this sets TERM (0 or 1). Default 0.")

# --- Main ---
if __name__ == "__main__":
    argv = sys.argv
    if len(argv) < 2:
        print_usage(); sys.exit(1)
    
    cmd = argv[1]
    if cmd in ("list", "get-all"): sys.exit(get_all())
    elif cmd == "get" and len(argv) > 2: sys.exit(get_gpio(argv[2]))
    elif cmd == "set" and len(argv) > 3: sys.exit(set_gpio(argv[2], argv[3]))
    elif cmd == "chips":
        for c in list_resolved_chips(): print(c)
    elif cmd == "apply-defaults":
        target = argv[2] if len(argv) > 2 else "all"
        sec = -1.0 if "--hold" in argv else None
        if "--for" in argv:
            try: sec = float(argv[argv.index("--for")+1])
            except: pass
        sys.exit(apply_defaults(target, hold_seconds=sec))
    elif cmd == "info" and len(argv) > 2:
        cfg = GPIO_PINS.get(argv[2])
        if cfg: print(f"{argv[2]}: {cfg}")
        sys.exit(0)
    elif cmd == "proto" and len(argv) > 3:
        extra = argv[4] if len(argv) > 4 else None
        sys.exit(set_protocol(argv[2].upper(), argv[3].lower(), extra))
    else:
        print_usage(); sys.exit(1)