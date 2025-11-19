"""
Input validation utilities for job automation tool.

Provides functions to validate configuration, email addresses, phone numbers,
file paths, and URLs.
"""

import re
from pathlib import Path
from typing import Any, Dict, List, Tuple
from urllib.parse import urlparse

from utils.logger import log_error, log_debug


def validate_email(email: str) -> bool:
    """
    Validate email address format.

    Args:
        email: Email address to validate.

    Returns:
        True if valid, False otherwise.
    """
    pattern = r"^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$"
    is_valid = bool(re.match(pattern, email))

    if not is_valid:
        log_debug(f"Invalid email format: {email}")

    return is_valid


def validate_phone(phone: str) -> bool:
    """
    Validate phone number format.

    Supports international and US formats:
    - +1-234-567-8900
    - (234) 567-8900
    - 234-567-8900
    - 2345678900

    Args:
        phone: Phone number to validate.

    Returns:
        True if valid, False otherwise.
    """
    pattern = r"^\+?1?[-.\s]?\(?[0-9]{3}\)?[-.\s]?[0-9]{3}[-.\s]?[0-9]{4}$"
    is_valid = bool(re.match(pattern, phone.strip()))

    if not is_valid:
        log_debug(f"Invalid phone format: {phone}")

    return is_valid


def validate_file_path(file_path: str, must_exist: bool = False) -> bool:
    """
    Validate file path.

    Args:
        file_path: File path to validate.
        must_exist: If True, file must exist (default: False).

    Returns:
        True if valid, False otherwise.
    """
    try:
        path = Path(file_path)

        if must_exist and not path.exists():
            log_debug(f"File path does not exist: {file_path}")
            return False

        if must_exist and not path.is_file():
            log_debug(f"Path is not a file: {file_path}")
            return False

        if path.parts and path.parts[0] in (".", ".."):
            log_debug(f"Relative paths not allowed: {file_path}")
            return False

        return True

    except (ValueError, TypeError) as e:
        log_debug(f"Invalid file path {file_path}: {e}")
        return False


def validate_url(url: str) -> bool:
    """
    Validate URL format.

    Args:
        url: URL to validate.

    Returns:
        True if valid, False otherwise.
    """
    try:
        result = urlparse(url)
        is_valid = all([result.scheme in ("http", "https"), result.netloc])

        if not is_valid:
            log_debug(f"Invalid URL format: {url}")

        return is_valid

    except Exception as e:
        log_debug(f"URL validation error for {url}: {e}")
        return False


def validate_config(config: Dict[str, Any]) -> Tuple[bool, List[str]]:
    """
    Validate configuration dictionary.

    Required keys:
    - platforms: List of platform configs
    - credentials: Dict with email and password

    Optional keys:
    - job_titles: List of job titles
    - locations: List of locations
    - max_applications: Maximum applications per session
    - headless: Run browser in headless mode

    Args:
        config: Configuration dictionary to validate.

    Returns:
        Tuple of (is_valid, list_of_errors).
    """
    errors: List[str] = []

    if not isinstance(config, dict):
        return False, ["Configuration must be a dictionary"]

    required_keys = ["platforms", "credentials"]
    for key in required_keys:
        if key not in config:
            errors.append(f"Missing required key: {key}")

    if errors:
        return False, errors

    if not isinstance(config.get("platforms"), list) or not config["platforms"]:
        errors.append("'platforms' must be a non-empty list")

    if not isinstance(config.get("credentials"), dict):
        errors.append("'credentials' must be a dictionary")
    else:
        credentials = config["credentials"]
        if "email" not in credentials:
            errors.append("Missing 'credentials.email'")
        elif not validate_email(credentials["email"]):
            errors.append(f"Invalid email in credentials: {credentials['email']}")

        if "password" not in credentials:
            errors.append("Missing 'credentials.password'")
        elif not isinstance(credentials["password"], str) or len(credentials["password"]) < 6:
            errors.append("Password must be at least 6 characters")

    optional_keys = {
        "job_titles": list,
        "locations": list,
        "max_applications": int,
        "headless": bool,
        "timeout": int,
        "wait_time": int,
    }

    for key, expected_type in optional_keys.items():
        if key in config and not isinstance(config[key], expected_type):
            errors.append(f"'{key}' must be of type {expected_type.__name__}")

    if "max_applications" in config and config["max_applications"] < 1:
        errors.append("'max_applications' must be at least 1")

    if "timeout" in config and config["timeout"] < 5:
        errors.append("'timeout' must be at least 5 seconds")

    if "platforms" in config:
        for idx, platform in enumerate(config["platforms"]):
            if not isinstance(platform, dict):
                errors.append(f"Platform {idx} must be a dictionary")
                continue

            if "name" not in platform:
                errors.append(f"Platform {idx} missing 'name'")

            if not isinstance(platform.get("name"), str):
                errors.append(f"Platform {idx} 'name' must be a string")

    is_valid = len(errors) == 0

    if not is_valid:
        for error in errors:
            log_error(f"Config validation error: {error}")

    return is_valid, errors
