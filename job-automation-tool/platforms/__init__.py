"""
Platform registry and factory for job automation tool.

Provides dynamic platform loading and initialization.
"""

from typing import Dict, Type, Optional
from .base_platform import AbstractBasePlatform
from .indeed import IndeedPlatform
from .dice import DicePlatform
from .ziprecruiter import ZipRecruiterPlatform

# Registry of available platforms
PLATFORM_REGISTRY: Dict[str, Type[AbstractBasePlatform]] = {
    'indeed': IndeedPlatform,
    'dice': DicePlatform,
    'ziprecruiter': ZipRecruiterPlatform,
}


def get_platform(platform_name: str, **kwargs) -> Optional[AbstractBasePlatform]:
    """
    Get platform instance by name.

    Args:
        platform_name: Name of the platform (e.g., 'indeed', 'dice')
        **kwargs: Arguments to pass to platform constructor

    Returns:
        Platform instance or None if platform not found
    """
    platform_name = platform_name.lower().strip()

    if platform_name not in PLATFORM_REGISTRY:
        return None

    platform_class = PLATFORM_REGISTRY[platform_name]
    return platform_class(**kwargs)


def list_available_platforms() -> list:
    """Get list of available platforms."""
    return list(PLATFORM_REGISTRY.keys())


def register_platform(name: str, platform_class: Type[AbstractBasePlatform]) -> None:
    """
    Register a new platform.

    Args:
        name: Platform name
        platform_class: Platform class (must inherit from AbstractBasePlatform)
    """
    if not issubclass(platform_class, AbstractBasePlatform):
        raise TypeError(f"{platform_class} must inherit from AbstractBasePlatform")
    PLATFORM_REGISTRY[name.lower()] = platform_class


__all__ = [
    'get_platform',
    'list_available_platforms',
    'register_platform',
    'PLATFORM_REGISTRY',
    'AbstractBasePlatform',
    'IndeedPlatform',
    'DicePlatform',
    'ZipRecruiterPlatform',
]
