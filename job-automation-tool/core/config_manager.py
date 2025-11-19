"""
Configuration management module for job automation tool.

Handles loading, validating, and merging configuration from files and environment.
"""

import os
import json
from pathlib import Path
from typing import Any, Dict, Optional
from dataclasses import dataclass, asdict, field

from utils.logger import log_info, log_error, log_debug
from utils.validators import validate_config


@dataclass
class Credentials:
    """User credentials for job application."""

    email: str
    password: str

    def to_dict(self) -> Dict[str, str]:
        """Convert to dictionary."""
        return asdict(self)


@dataclass
class PlatformConfig:
    """Configuration for a job platform."""

    name: str
    url: str
    enabled: bool = True
    credentials_override: Optional[Dict[str, str]] = None

    def to_dict(self) -> Dict[str, Any]:
        """Convert to dictionary."""
        return asdict(self)


@dataclass
class JobSearchCriteria:
    """Job search criteria."""

    job_titles: list = field(default_factory=list)
    locations: list = field(default_factory=list)
    keywords: list = field(default_factory=list)
    exclude_keywords: list = field(default_factory=list)

    def to_dict(self) -> Dict[str, list]:
        """Convert to dictionary."""
        return asdict(self)


class ConfigManager:
    """Manage configuration for job automation tool."""

    DEFAULT_CONFIG = {
        "timeout": 30,
        "wait_time": 5,
        "headless": False,
        "max_applications": 100,
        "screenshot_on_error": True,
        "log_level": "INFO",
    }

    def __init__(self):
        """Initialize ConfigManager."""
        self.config: Dict[str, Any] = self.DEFAULT_CONFIG.copy()
        self.platforms: Dict[str, PlatformConfig] = {}
        self.credentials: Optional[Credentials] = None
        self.search_criteria: Optional[JobSearchCriteria] = None
        log_debug("ConfigManager initialized")

    def load_config(self, config_path: str) -> bool:
        """
        Load configuration from JSON file.

        Merges with environment variables and default values.

        Args:
            config_path: Path to configuration file.

        Returns:
            True if loaded successfully, False otherwise.

        Raises:
            FileNotFoundError: If configuration file not found.
            json.JSONDecodeError: If JSON is invalid.
        """
        config_file = Path(config_path)

        if not config_file.exists():
            raise FileNotFoundError(f"Configuration file not found: {config_path}")

        if not config_file.is_file():
            raise FileNotFoundError(f"Configuration path is not a file: {config_path}")

        try:
            with open(config_file, "r", encoding="utf-8") as f:
                file_config = json.load(f)

            log_info(f"Loaded configuration from {config_path}")

        except json.JSONDecodeError as e:
            log_error(f"Invalid JSON in configuration file: {e}")
            raise

        except Exception as e:
            log_error(f"Error reading configuration file: {e}")
            raise

        return self._process_config(file_config)

    def load_config_dict(self, config_dict: Dict[str, Any]) -> bool:
        """
        Load configuration from dictionary.

        Args:
            config_dict: Configuration dictionary.

        Returns:
            True if loaded successfully, False otherwise.
        """
        return self._process_config(config_dict)

    def _process_config(self, file_config: Dict[str, Any]) -> bool:
        """
        Process and merge configuration.

        Args:
            file_config: Configuration from file or dict.

        Returns:
            True if processed successfully, False otherwise.
        """
        is_valid, errors = validate_config(file_config)

        if not is_valid:
            log_error(f"Configuration validation failed: {errors}")
            return False

        self._merge_with_environment(file_config)

        self.config.update(file_config)

        if "credentials" in file_config:
            self.credentials = Credentials(**file_config["credentials"])
            log_debug("Credentials loaded")

        if "platforms" in file_config:
            for platform_config in file_config["platforms"]:
                platform = PlatformConfig(**platform_config)
                self.platforms[platform.name] = platform
            log_info(f"Loaded {len(self.platforms)} platform(s)")

        if "search_criteria" in file_config:
            criteria_data = file_config["search_criteria"]
            self.search_criteria = JobSearchCriteria(
                job_titles=criteria_data.get("job_titles", []),
                locations=criteria_data.get("locations", []),
                keywords=criteria_data.get("keywords", []),
                exclude_keywords=criteria_data.get("exclude_keywords", []),
            )
            log_debug("Search criteria loaded")

        log_info("Configuration processed successfully")
        return True

    def _merge_with_environment(self, config: Dict[str, Any]) -> None:
        """
        Merge environment variables into configuration.

        Environment variables take precedence over config file.

        Supported environment variables:
        - JOB_AUTOMATION_TIMEOUT: Request timeout
        - JOB_AUTOMATION_HEADLESS: Run in headless mode
        - JOB_AUTOMATION_MAX_APPS: Maximum applications
        - JOB_AUTOMATION_LOG_LEVEL: Logging level
        - JOB_AUTOMATION_EMAIL: Email override
        - JOB_AUTOMATION_PASSWORD: Password override

        Args:
            config: Configuration dictionary to update.
        """
        env_mappings = {
            "JOB_AUTOMATION_TIMEOUT": ("timeout", int),
            "JOB_AUTOMATION_HEADLESS": ("headless", lambda x: x.lower() in ("true", "1", "yes")),
            "JOB_AUTOMATION_MAX_APPS": ("max_applications", int),
            "JOB_AUTOMATION_LOG_LEVEL": ("log_level", str),
        }

        for env_var, (config_key, converter) in env_mappings.items():
            value = os.getenv(env_var)
            if value is not None:
                try:
                    config[config_key] = converter(value)
                    log_debug(f"Configuration override from {env_var}: {config_key}")
                except (ValueError, TypeError) as e:
                    log_error(f"Invalid value for {env_var}: {e}")

        if os.getenv("JOB_AUTOMATION_EMAIL"):
            if "credentials" not in config:
                config["credentials"] = {}
            config["credentials"]["email"] = os.getenv("JOB_AUTOMATION_EMAIL")
            log_debug("Email override from environment")

        if os.getenv("JOB_AUTOMATION_PASSWORD"):
            if "credentials" not in config:
                config["credentials"] = {}
            config["credentials"]["password"] = os.getenv("JOB_AUTOMATION_PASSWORD")
            log_debug("Password override from environment")

    def get(self, key: str, default: Any = None) -> Any:
        """
        Get configuration value.

        Args:
            key: Configuration key.
            default: Default value if key not found.

        Returns:
            Configuration value or default.
        """
        return self.config.get(key, default)

    def set(self, key: str, value: Any) -> None:
        """
        Set configuration value.

        Args:
            key: Configuration key.
            value: Configuration value.
        """
        self.config[key] = value
        log_debug(f"Configuration set: {key} = {value}")

    def get_platform(self, platform_name: str) -> Optional[PlatformConfig]:
        """
        Get platform configuration.

        Args:
            platform_name: Name of the platform.

        Returns:
            PlatformConfig or None if not found.
        """
        return self.platforms.get(platform_name)

    def get_enabled_platforms(self) -> Dict[str, PlatformConfig]:
        """
        Get all enabled platforms.

        Returns:
            Dictionary of enabled platform configurations.
        """
        return {name: config for name, config in self.platforms.items() if config.enabled}

    def get_credentials(self) -> Optional[Credentials]:
        """
        Get user credentials.

        Returns:
            Credentials object or None if not loaded.
        """
        return self.credentials

    def get_search_criteria(self) -> Optional[JobSearchCriteria]:
        """
        Get job search criteria.

        Returns:
            JobSearchCriteria object or None if not loaded.
        """
        return self.search_criteria

    def to_dict(self) -> Dict[str, Any]:
        """
        Convert configuration to dictionary (without sensitive data).

        Returns:
            Configuration dictionary with masked credentials.
        """
        config_dict = self.config.copy()

        if self.credentials:
            config_dict["credentials"] = {
                "email": self.credentials.email,
                "password": "***masked***",
            }

        config_dict["platforms"] = {
            name: platform.to_dict() for name, platform in self.platforms.items()
        }

        if self.search_criteria:
            config_dict["search_criteria"] = self.search_criteria.to_dict()

        return config_dict

    def validate(self) -> bool:
        """
        Validate current configuration.

        Returns:
            True if valid, False otherwise.
        """
        if not self.credentials:
            log_error("No credentials configured")
            return False

        if not self.platforms:
            log_error("No platforms configured")
            return False

        if len(self.get_enabled_platforms()) == 0:
            log_error("No enabled platforms found")
            return False

        log_info("Configuration validation passed")
        return True
