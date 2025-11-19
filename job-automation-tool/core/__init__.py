"""
Core modules for job automation tool.
"""

from core.bot import JobApplicationBot
from core.browser_manager import BrowserManager
from core.config_manager import ConfigManager
from core.application_tracker import ApplicationTracker

__all__ = [
    "JobApplicationBot",
    "BrowserManager",
    "ConfigManager",
    "ApplicationTracker",
]
