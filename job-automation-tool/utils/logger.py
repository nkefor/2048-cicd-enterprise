"""
Advanced logging module with file and console output.

Provides setup_logger() for configuration and helper functions for different log levels.
Includes rotating file handler and color-coded console output.
"""

import logging
import logging.handlers
import sys
from pathlib import Path
from typing import Optional
from datetime import datetime


class ColoredFormatter(logging.Formatter):
    """Custom formatter with color-coded output for console."""

    COLORS = {
        logging.DEBUG: "\033[36m",      # Cyan
        logging.INFO: "\033[32m",       # Green
        logging.WARNING: "\033[33m",    # Yellow
        logging.ERROR: "\033[31m",      # Red
        logging.CRITICAL: "\033[35m",   # Magenta
    }
    RESET = "\033[0m"

    def format(self, record: logging.LogRecord) -> str:
        """Format log record with color-coded level."""
        log_color = self.COLORS.get(record.levelno, self.RESET)
        record.levelname = f"{log_color}{record.levelname}{self.RESET}"
        return super().format(record)


def setup_logger(
    name: str = "job_automation",
    log_dir: str = "logs",
    log_level: int = logging.INFO,
    max_bytes: int = 10485760,  # 10MB
    backup_count: int = 5,
) -> logging.Logger:
    """
    Set up logger with file and console handlers.

    Args:
        name: Logger name.
        log_dir: Directory to store log files.
        log_level: Logging level (default: INFO).
        max_bytes: Maximum size of log file before rotation (default: 10MB).
        backup_count: Number of backup log files to keep (default: 5).

    Returns:
        Configured logger instance.

    Raises:
        OSError: If log directory cannot be created.
    """
    logger = logging.getLogger(name)
    logger.setLevel(log_level)

    if logger.hasHandlers():
        return logger

    log_path = Path(log_dir)
    try:
        log_path.mkdir(parents=True, exist_ok=True)
    except OSError as e:
        raise OSError(f"Cannot create log directory {log_dir}: {e}")

    log_format = (
        "%(asctime)s - %(name)s - %(levelname)s - "
        "[%(filename)s:%(lineno)d] - %(message)s"
    )
    date_format = "%Y-%m-%d %H:%M:%S"

    formatter = logging.Formatter(log_format, datefmt=date_format)
    colored_formatter = ColoredFormatter(log_format, datefmt=date_format)

    file_handler = logging.handlers.RotatingFileHandler(
        log_path / f"{name}.log",
        maxBytes=max_bytes,
        backupCount=backup_count,
    )
    file_handler.setLevel(log_level)
    file_handler.setFormatter(formatter)

    console_handler = logging.StreamHandler(sys.stdout)
    console_handler.setLevel(log_level)
    console_handler.setFormatter(colored_formatter)

    logger.addHandler(file_handler)
    logger.addHandler(console_handler)

    logger.info(f"Logger initialized: {name}")
    return logger


_logger: Optional[logging.Logger] = None


def _get_logger() -> logging.Logger:
    """Get or create default logger instance."""
    global _logger
    if _logger is None:
        _logger = setup_logger()
    return _logger


def log_info(message: str, *args, **kwargs) -> None:
    """
    Log info level message.

    Args:
        message: Log message.
        *args: Positional arguments for message formatting.
        **kwargs: Keyword arguments for message formatting.
    """
    _get_logger().info(message, *args, **kwargs)


def log_error(message: str, *args, exc_info: bool = False, **kwargs) -> None:
    """
    Log error level message.

    Args:
        message: Log message.
        *args: Positional arguments for message formatting.
        exc_info: Include exception info if True.
        **kwargs: Keyword arguments for message formatting.
    """
    _get_logger().error(message, *args, exc_info=exc_info, **kwargs)


def log_warning(message: str, *args, **kwargs) -> None:
    """
    Log warning level message.

    Args:
        message: Log message.
        *args: Positional arguments for message formatting.
        **kwargs: Keyword arguments for message formatting.
    """
    _get_logger().warning(message, *args, **kwargs)


def log_debug(message: str, *args, **kwargs) -> None:
    """
    Log debug level message.

    Args:
        message: Log message.
        *args: Positional arguments for message formatting.
        **kwargs: Keyword arguments for message formatting.
    """
    _get_logger().debug(message, *args, **kwargs)
