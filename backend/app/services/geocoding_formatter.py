MAX_DESCRIPTION_LENGTH = 120


def _truncate_text(text: str, max_length: int = MAX_DESCRIPTION_LENGTH) -> str:
    cleaned = " ".join(text.split())
    if len(cleaned) <= max_length:
        return cleaned
    return f"{cleaned[: max_length - 3].rstrip(' ,')}..."


def format_nominatim_address(payload: object) -> str | None:
    """Format a concise human-readable description from Nominatim JSON."""
    if not isinstance(payload, dict):
        return None

    address = payload.get("address")
    if isinstance(address, dict):
        candidates = (
            address.get("road"),
            address.get("neighbourhood")
            or address.get("quarter")
            or address.get("residential"),
            address.get("suburb"),
            address.get("city")
            or address.get("town")
            or address.get("village")
            or address.get("municipality"),
            address.get("state"),
        )
        parts: list[str] = []
        seen: set[str] = set()
        for value in candidates:
            if isinstance(value, str) and value.strip():
                trimmed = value.strip()
                if trimmed.lower() not in seen:
                    seen.add(trimmed.lower())
                    parts.append(trimmed)
        if parts:
            return _truncate_text(", ".join(parts))

    display_name = payload.get("display_name")
    if isinstance(display_name, str) and display_name.strip():
        return _truncate_text(display_name.strip())
    return None
