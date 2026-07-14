def lift_height_action(
    pressed_keys,
    current_height_mm: float,
    step_mm: float,
    soft_min_mm: float,
    soft_max_mm: float,
    up_key: str = "u",
    down_key: str = "j",
) -> dict[str, float | int]:
    """Build the bounded lift target used by GUI dataset recording."""
    up_pressed = up_key in pressed_keys
    down_pressed = down_key in pressed_keys
    current = float(current_height_mm)

    if not up_pressed and not down_pressed:
        return {"lift_axis.height_mm": current, "lift_axis.vel": 0}

    direction = int(up_pressed) - int(down_pressed)
    target = current + direction * max(float(step_mm), 0.0)
    target = min(max(target, float(soft_min_mm)), float(soft_max_mm))
    return {"lift_axis.height_mm": target}


def with_direct_lift_velocity(
    action: dict,
    current_height_mm: float,
    velocity: int,
) -> dict:
    """Add a continuous wire command while retaining the recorded height target."""
    wire_action = dict(action)
    if "lift_axis.height_mm" not in action or "lift_axis.vel" in action:
        return wire_action

    error = float(action["lift_axis.height_mm"]) - float(current_height_mm)
    if error > 0:
        wire_action["lift_axis.vel"] = abs(int(velocity))
    elif error < 0:
        wire_action["lift_axis.vel"] = -abs(int(velocity))
    else:
        wire_action["lift_axis.vel"] = 0
    return wire_action
