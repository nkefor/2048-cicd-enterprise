"""
Main job automation bot orchestrator.

Handles platform processing, session management, and error recovery.
"""

import time
from typing import Optional, Dict, List, Callable, Any
from abc import ABC, abstractmethod
from datetime import datetime
from functools import wraps

from core.browser_manager import BrowserManager
from core.config_manager import ConfigManager, PlatformConfig
from core.application_tracker import ApplicationTracker
from utils.logger import log_info, log_error, log_debug, log_warning
from utils.captcha_detector import detect_captcha


class PlatformHandler(ABC):
    """Abstract base class for platform handlers."""

    def __init__(self, browser_manager: BrowserManager, config_manager: ConfigManager):
        """
        Initialize platform handler.

        Args:
            browser_manager: BrowserManager instance.
            config_manager: ConfigManager instance.
        """
        self.browser_manager = browser_manager
        self.config_manager = config_manager

    @abstractmethod
    def login(self) -> bool:
        """
        Login to platform.

        Returns:
            True if successful, False otherwise.
        """
        pass

    @abstractmethod
    def search_jobs(self) -> List[Dict[str, str]]:
        """
        Search for jobs on platform.

        Returns:
            List of job postings.
        """
        pass

    @abstractmethod
    def apply_to_job(self, job: Dict[str, str]) -> bool:
        """
        Apply to a specific job.

        Args:
            job: Job posting dictionary.

        Returns:
            True if successful, False otherwise.
        """
        pass

    @abstractmethod
    def logout(self) -> None:
        """Logout from platform."""
        pass


def timeout_handler(timeout_seconds: int) -> Callable:
    """
    Decorator to handle timeout for platform processing.

    Args:
        timeout_seconds: Timeout duration in seconds.

    Returns:
        Decorator function.
    """

    def decorator(func: Callable) -> Callable:
        @wraps(func)
        def wrapper(*args, **kwargs) -> Any:
            start_time = time.time()
            timeout = timeout_seconds

            try:
                result = func(*args, **kwargs)
                elapsed = time.time() - start_time

                if elapsed > timeout:
                    log_warning(
                        f"{func.__name__} exceeded timeout: {elapsed:.2f}s > {timeout}s"
                    )

                return result

            except KeyboardInterrupt:
                log_warning(f"{func.__name__} interrupted by user")
                raise

            except Exception as e:
                elapsed = time.time() - start_time
                log_error(f"{func.__name__} failed after {elapsed:.2f}s: {e}")
                raise

        return wrapper

    return decorator


class JobApplicationBot:
    """Main bot orchestrator for job applications."""

    PLATFORM_FACTORIES: Dict[str, type] = {}

    def __init__(
        self,
        config_manager: ConfigManager,
        headless: bool = False,
        timeout: int = 30,
        max_retries: int = 3,
    ):
        """
        Initialize JobApplicationBot.

        Args:
            config_manager: ConfigManager instance.
            headless: Run browser in headless mode (default: False).
            timeout: Timeout for operations in seconds (default: 30).
            max_retries: Maximum retries for failed operations (default: 3).
        """
        self.config_manager = config_manager
        self.timeout = timeout
        self.max_retries = max_retries

        self.browser_manager = BrowserManager(
            headless=headless,
            timeout=timeout,
        )

        self.tracker = ApplicationTracker()
        self.platforms: Dict[str, PlatformHandler] = {}

        self.session_start_time: Optional[datetime] = None
        self.session_applications_count = 0
        self.session_errors_count = 0

        log_info(
            f"JobApplicationBot initialized: timeout={timeout}s, max_retries={max_retries}"
        )

    @classmethod
    def register_platform(cls, platform_name: str, handler_class: type) -> None:
        """
        Register a platform handler.

        Args:
            platform_name: Name of the platform.
            handler_class: Handler class for the platform.
        """
        cls.PLATFORM_FACTORIES[platform_name] = handler_class
        log_debug(f"Platform registered: {platform_name}")

    @classmethod
    def create_platform_handler(
        cls,
        platform_name: str,
        browser_manager: BrowserManager,
        config_manager: ConfigManager,
    ) -> Optional[PlatformHandler]:
        """
        Create platform handler using factory pattern.

        Args:
            platform_name: Name of the platform.
            browser_manager: BrowserManager instance.
            config_manager: ConfigManager instance.

        Returns:
            PlatformHandler instance or None if platform not registered.
        """
        handler_class = cls.PLATFORM_FACTORIES.get(platform_name)

        if handler_class is None:
            log_error(f"Platform handler not found: {platform_name}")
            return None

        try:
            return handler_class(browser_manager, config_manager)

        except Exception as e:
            log_error(f"Failed to create platform handler {platform_name}: {e}")
            return None

    def start_session(self) -> bool:
        """
        Start a job application session.

        Returns:
            True if session started successfully, False otherwise.
        """
        try:
            self.session_start_time = datetime.now()
            self.session_applications_count = 0
            self.session_errors_count = 0

            if not self.config_manager.validate():
                log_error("Configuration validation failed")
                return False

            log_info("Session started")
            return True

        except Exception as e:
            log_error(f"Failed to start session: {e}")
            return False

    def end_session(self) -> Dict[str, Any]:
        """
        End session and return statistics.

        Returns:
            Dictionary with session statistics.
        """
        if self.session_start_time is None:
            return {}

        elapsed_time = (datetime.now() - self.session_start_time).total_seconds()

        stats = {
            "start_time": self.session_start_time.isoformat(),
            "end_time": datetime.now().isoformat(),
            "duration_seconds": elapsed_time,
            "applications": self.session_applications_count,
            "errors": self.session_errors_count,
            "success_rate": (
                (
                    (self.session_applications_count - self.session_errors_count)
                    / self.session_applications_count
                    * 100
                )
                if self.session_applications_count > 0
                else 0
            ),
        }

        log_info(
            f"Session ended: {self.session_applications_count} applications, "
            f"{self.session_errors_count} errors, {elapsed_time:.2f}s elapsed"
        )

        return stats

    @timeout_handler(timeout_seconds=300)
    def process_platform(self, platform_name: str) -> bool:
        """
        Process a single platform with timeout protection.

        Args:
            platform_name: Name of the platform to process.

        Returns:
            True if processing successful, False otherwise.
        """
        platform_config = self.config_manager.get_platform(platform_name)

        if not platform_config:
            log_error(f"Platform configuration not found: {platform_name}")
            return False

        if not platform_config.enabled:
            log_debug(f"Platform disabled: {platform_name}")
            return True

        log_info(f"Processing platform: {platform_name}")

        try:
            self.browser_manager.create_driver()

            handler = self.create_platform_handler(
                platform_name,
                self.browser_manager,
                self.config_manager,
            )

            if handler is None:
                log_warning(f"No handler available for platform: {platform_name}")
                return False

            if not self._login_with_retry(handler):
                log_error(f"Failed to login to {platform_name}")
                return False

            jobs = handler.search_jobs()

            if not jobs:
                log_warning(f"No jobs found on {platform_name}")
                return True

            log_info(f"Found {len(jobs)} jobs on {platform_name}")

            applications_count = self._apply_to_jobs(handler, jobs, platform_name)

            log_info(f"Applied to {applications_count} jobs on {platform_name}")
            self.session_applications_count += applications_count

            handler.logout()
            return True

        except Exception as e:
            log_error(f"Error processing platform {platform_name}: {e}")
            self.session_errors_count += 1
            self.browser_manager.take_screenshot(f"error_{platform_name}")
            return False

        finally:
            self.browser_manager.quit()

    def _login_with_retry(self, handler: PlatformHandler) -> bool:
        """
        Login to platform with retry logic.

        Args:
            handler: PlatformHandler instance.

        Returns:
            True if login successful, False otherwise.
        """
        for attempt in range(1, self.max_retries + 1):
            try:
                log_debug(f"Login attempt {attempt}/{self.max_retries}")

                if handler.login():
                    log_info("Login successful")
                    return True

                self.browser_manager.take_screenshot(f"login_failed_attempt_{attempt}")

                if attempt < self.max_retries:
                    wait_time = 5 * attempt
                    log_warning(f"Login failed, retrying in {wait_time}s")
                    time.sleep(wait_time)

            except Exception as e:
                log_error(f"Login attempt {attempt} failed: {e}")

                if attempt < self.max_retries:
                    time.sleep(5 * attempt)

        log_error(f"Login failed after {self.max_retries} attempts")
        return False

    def _apply_to_jobs(
        self, handler: PlatformHandler, jobs: List[Dict[str, str]], platform_name: str
    ) -> int:
        """
        Apply to multiple jobs.

        Args:
            handler: PlatformHandler instance.
            jobs: List of job postings.
            platform_name: Platform name.

        Returns:
            Number of successful applications.
        """
        applications_count = 0
        max_applications = self.config_manager.get("max_applications", 100)

        for idx, job in enumerate(jobs):
            if applications_count >= max_applications:
                log_info(f"Reached maximum applications limit: {max_applications}")
                break

            try:
                job_url = job.get("url", "")

                if not job_url:
                    log_warning(f"Job {idx + 1} has no URL, skipping")
                    continue

                if self.tracker.has_applied_to(job_url):
                    log_debug(f"Already applied to: {job_url}")
                    continue

                if self._check_captcha():
                    log_warning("CAPTCHA detected, pausing applications")
                    break

                if handler.apply_to_job(job):
                    company = job.get("company", "Unknown")
                    title = job.get("title", "Unknown")

                    success, app_id = self.tracker.track_application(
                        job_title=title,
                        company=company,
                        location=job.get("location", ""),
                        platform=platform_name,
                        url=job_url,
                        status="applied",
                    )

                    if success:
                        applications_count += 1
                        log_info(f"Applied to {company} - {title}")
                    else:
                        log_warning(f"Failed to track application: {title}")

                else:
                    log_debug(f"Failed to apply to job: {title}")

            except Exception as e:
                log_error(f"Error applying to job {idx + 1}: {e}")
                self.session_errors_count += 1
                continue

        return applications_count

    def _check_captcha(self) -> bool:
        """
        Check if CAPTCHA is present.

        Returns:
            True if CAPTCHA detected, False otherwise.
        """
        try:
            if self.browser_manager.driver is None:
                return False

            captcha_detected, confidence = detect_captcha(self.browser_manager.driver)

            if captcha_detected:
                log_warning(f"CAPTCHA detected with confidence {confidence:.2f}")
                return True

            return False

        except Exception as e:
            log_debug(f"Error checking for CAPTCHA: {e}")
            return False

    def process_all_platforms(self) -> Dict[str, bool]:
        """
        Process all enabled platforms.

        Returns:
            Dictionary mapping platform names to success status.
        """
        if not self.start_session():
            return {}

        results: Dict[str, bool] = {}

        enabled_platforms = self.config_manager.get_enabled_platforms()

        for platform_name in enabled_platforms.keys():
            try:
                success = self.process_platform(platform_name)
                results[platform_name] = success

            except Exception as e:
                log_error(f"Error processing platform {platform_name}: {e}")
                results[platform_name] = False

        stats = self.end_session()
        log_info(f"Session statistics: {stats}")

        return results

    def get_statistics(self) -> Dict[str, Any]:
        """
        Get application statistics from database.

        Returns:
            Statistics dictionary.
        """
        return self.tracker.get_statistics()

    def get_recent_applications(self, limit: int = 10) -> List[Dict[str, str]]:
        """
        Get recent applications.

        Args:
            limit: Number of applications to retrieve (default: 10).

        Returns:
            List of recent applications.
        """
        applications = self.tracker.get_recent_applications(limit)

        return [
            {
                "id": app.id,
                "job_title": app.job_title,
                "company": app.company,
                "location": app.location,
                "platform": app.platform,
                "applied_at": app.applied_at,
                "status": app.status,
                "url": app.url,
                "notes": app.notes,
            }
            for app in applications
        ]

    def cleanup(self) -> None:
        """Cleanup resources."""
        try:
            self.browser_manager.quit()
            log_info("Cleanup completed")

        except Exception as e:
            log_error(f"Error during cleanup: {e}")

    def __enter__(self):
        """Context manager entry."""
        return self

    def __exit__(self, exc_type, exc_val, exc_tb):
        """Context manager exit."""
        self.cleanup()
        if exc_type is not None:
            log_error(f"Exception in context: {exc_val}")
        return False
