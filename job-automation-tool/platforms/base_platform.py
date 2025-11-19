"""
Abstract base class for job application platforms.

Defines interface and common utilities for all platform implementations.
"""

from abc import ABC, abstractmethod
from typing import Dict, List, Optional, Tuple
from datetime import datetime
import time
import random

from selenium.webdriver.remote.webdriver import WebDriver
from selenium.webdriver.common.by import By
from selenium.webdriver.support.ui import WebDriverWait, Select
from selenium.webdriver.support import expected_conditions as EC
from selenium.webdriver.common.keys import Keys
from selenium.common.exceptions import (
    TimeoutException,
    NoSuchElementException,
    StaleElementReferenceException,
    WebDriverException,
)

from utils.logger import log_info, log_error, log_debug, log_warning


class AbstractBasePlatform(ABC):
    """Abstract base class for job application platforms."""

    # Platform identification
    PLATFORM_NAME: str = "base"
    PLATFORM_URL: str = "https://example.com"

    # Timing constants (in seconds)
    SHORT_DELAY = 0.5
    MEDIUM_DELAY = 2
    LONG_DELAY = 5
    PAGE_LOAD_TIMEOUT = 15

    def __init__(self, driver: WebDriver, config: Dict):
        """
        Initialize platform instance.

        Args:
            driver: Selenium WebDriver instance
            config: Configuration dictionary with login credentials and preferences
        """
        self.driver = driver
        self.config = config
        self.logger_prefix = f"[{self.PLATFORM_NAME.upper()}]"
        self.applications_count = 0
        self.success_count = 0
        self.failure_count = 0
        self.start_time = datetime.now()

    # Abstract methods - must be implemented by subclasses

    @abstractmethod
    def login(self, email: str, password: str) -> bool:
        """
        Authenticate with the platform.

        Args:
            email: User email/username
            password: User password

        Returns:
            True if login successful, False otherwise
        """
        pass

    @abstractmethod
    def search_jobs(self, keywords: str, location: str = "") -> List[Dict]:
        """
        Search for jobs on the platform.

        Args:
            keywords: Job search keywords
            location: Job location filter

        Returns:
            List of job dictionaries with 'title', 'company', 'url' keys
        """
        pass

    @abstractmethod
    def apply_to_job(self, job: Dict, profile: Dict) -> bool:
        """
        Apply to a specific job.

        Args:
            job: Job dictionary with 'title', 'company', 'url' keys
            profile: User profile dictionary with personal info

        Returns:
            True if application successful, False otherwise
        """
        pass

    # Common utility methods

    def _random_delay(self, min_seconds: float = None, max_seconds: float = None) -> None:
        """
        Sleep for random duration to simulate human behavior.

        Args:
            min_seconds: Minimum delay (uses SHORT_DELAY if None)
            max_seconds: Maximum delay (uses MEDIUM_DELAY if None)
        """
        min_seconds = min_seconds or self.SHORT_DELAY
        max_seconds = max_seconds or self.MEDIUM_DELAY
        delay = random.uniform(min_seconds, max_seconds)
        time.sleep(delay)

    def navigate_to(self, url: str, wait_element: Optional[str] = None) -> bool:
        """
        Navigate to a URL and optionally wait for element.

        Args:
            url: URL to navigate to
            wait_element: CSS selector to wait for after loading

        Returns:
            True if navigation successful, False otherwise
        """
        try:
            self._random_delay()
            self.driver.get(url)
            log_debug(f"{self.logger_prefix} Navigated to {url}")

            if wait_element:
                self.wait_for_element(wait_element)

            return True

        except WebDriverException as e:
            log_error(f"{self.logger_prefix} Navigation failed to {url}: {e}")
            return False

    def wait_for_element(
        self,
        selector: str,
        by: By = By.CSS_SELECTOR,
        timeout: int = None,
    ) -> Optional[any]:
        """
        Wait for element to be present on page.

        Args:
            selector: Selector string
            by: Selenium By locator type
            timeout: Timeout in seconds

        Returns:
            WebElement or None if timeout
        """
        timeout = timeout or self.PAGE_LOAD_TIMEOUT

        try:
            element = WebDriverWait(self.driver, timeout).until(
                EC.presence_of_element_located((by, selector))
            )
            log_debug(f"{self.logger_prefix} Found element: {selector}")
            return element

        except TimeoutException:
            log_warning(f"{self.logger_prefix} Timeout waiting for: {selector}")
            return None

        except Exception as e:
            log_error(f"{self.logger_prefix} Error waiting for element: {e}")
            return None

    def wait_for_element_clickable(
        self,
        selector: str,
        by: By = By.CSS_SELECTOR,
        timeout: int = None,
    ) -> Optional[any]:
        """
        Wait for element to be clickable.

        Args:
            selector: Selector string
            by: Selenium By locator type
            timeout: Timeout in seconds

        Returns:
            WebElement or None if timeout
        """
        timeout = timeout or self.PAGE_LOAD_TIMEOUT

        try:
            element = WebDriverWait(self.driver, timeout).until(
                EC.element_to_be_clickable((by, selector))
            )
            return element

        except TimeoutException:
            log_warning(f"{self.logger_prefix} Element not clickable: {selector}")
            return None

        except Exception as e:
            log_error(f"{self.logger_prefix} Error waiting for clickable element: {e}")
            return None

    def find_element(
        self,
        selector: str,
        by: By = By.CSS_SELECTOR,
    ) -> Optional[any]:
        """
        Find element without waiting.

        Args:
            selector: Selector string
            by: Selenium By locator type

        Returns:
            WebElement or None
        """
        try:
            return self.driver.find_element(by, selector)
        except NoSuchElementException:
            return None
        except Exception as e:
            log_debug(f"{self.logger_prefix} Error finding element: {e}")
            return None

    def find_elements(
        self,
        selector: str,
        by: By = By.CSS_SELECTOR,
    ) -> List[any]:
        """
        Find multiple elements.

        Args:
            selector: Selector string
            by: Selenium By locator type

        Returns:
            List of WebElements
        """
        try:
            return self.driver.find_elements(by, selector)
        except Exception as e:
            log_debug(f"{self.logger_prefix} Error finding elements: {e}")
            return []

    def safe_click(self, element) -> bool:
        """
        Click element with error handling.

        Args:
            element: WebElement to click

        Returns:
            True if click successful, False otherwise
        """
        try:
            self._random_delay(self.SHORT_DELAY, self.SHORT_DELAY * 2)
            element.click()
            log_debug(f"{self.logger_prefix} Element clicked")
            return True

        except StaleElementReferenceException:
            log_warning(f"{self.logger_prefix} Element became stale before clicking")
            return False

        except Exception as e:
            log_error(f"{self.logger_prefix} Click failed: {e}")
            return False

    def safe_send_keys(self, element, text: str, clear_first: bool = True) -> bool:
        """
        Send keys to element with human-like behavior.

        Args:
            element: WebElement to send keys to
            text: Text to type
            clear_first: Clear field before typing

        Returns:
            True if successful, False otherwise
        """
        try:
            if clear_first:
                element.clear()
                self._random_delay(self.SHORT_DELAY)

            for char in text:
                element.send_keys(char)
                self._random_delay(0.02, 0.1)

            log_debug(f"{self.logger_prefix} Typed {len(text)} characters")
            return True

        except Exception as e:
            log_error(f"{self.logger_prefix} Send keys failed: {e}")
            return False

    def fill_form(self, fields: Dict[str, Tuple[str, str]]) -> int:
        """
        Fill form with multiple fields.

        Args:
            fields: Dict with field_name: (selector, value) pairs

        Returns:
            Number of fields successfully filled
        """
        filled_count = 0

        for field_name, (selector, value) in fields.items():
            try:
                element = self.wait_for_element(selector)
                if not element:
                    continue

                tag_name = element.tag_name.lower()

                if tag_name == 'select':
                    select = Select(element)
                    select.select_by_value(value)
                else:
                    if not self.safe_send_keys(element, value):
                        continue

                filled_count += 1
                self._random_delay()

            except Exception as e:
                log_warning(f"{self.logger_prefix} Failed to fill {field_name}: {e}")

        log_info(f"{self.logger_prefix} Filled {filled_count}/{len(fields)} form fields")
        return filled_count

    def is_logged_in(self, indicator_selector: Optional[str] = None) -> bool:
        """
        Check if currently logged in.

        Args:
            indicator_selector: Selector for logged-in indicator element

        Returns:
            True if logged in, False otherwise
        """
        if not indicator_selector:
            return True

        return self.find_element(indicator_selector) is not None

    def scroll_page(self, amount: int = 3, direction: str = "down") -> None:
        """
        Scroll page to simulate human behavior.

        Args:
            amount: Number of scroll iterations
            direction: 'up' or 'down'
        """
        try:
            scroll_script = f"window.scrollBy(0, {300 if direction == 'down' else -300})"

            for _ in range(amount):
                self.driver.execute_script(scroll_script)
                self._random_delay(0.5, 1.0)

            log_debug(f"{self.logger_prefix} Scrolled {amount} times")

        except Exception as e:
            log_debug(f"{self.logger_prefix} Scroll failed: {e}")

    def execute_script(self, script: str, *args) -> Optional[any]:
        """
        Execute JavaScript.

        Args:
            script: JavaScript code
            *args: Arguments to pass to script

        Returns:
            Script result or None
        """
        try:
            return self.driver.execute_script(script, *args)
        except Exception as e:
            log_error(f"{self.logger_prefix} Script execution failed: {e}")
            return None

    def get_current_url(self) -> str:
        """Get current page URL."""
        return self.driver.current_url

    def get_page_source(self) -> str:
        """Get page HTML source."""
        return self.driver.page_source

    def take_screenshot(self, name: str) -> None:
        """
        Take screenshot for debugging.

        Args:
            name: Screenshot name
        """
        try:
            timestamp = datetime.now().strftime("%Y%m%d_%H%M%S")
            filename = f"screenshots/{self.PLATFORM_NAME}_{name}_{timestamp}.png"
            self.driver.save_screenshot(filename)
            log_info(f"{self.logger_prefix} Screenshot saved: {filename}")
        except Exception as e:
            log_warning(f"{self.logger_prefix} Failed to take screenshot: {e}")

    def record_success(self, job_title: str) -> None:
        """Record successful application."""
        self.applications_count += 1
        self.success_count += 1
        log_info(f"{self.logger_prefix} ✓ Applied successfully to {job_title}")

    def record_failure(self, job_title: str, reason: str = "Unknown") -> None:
        """Record failed application."""
        self.applications_count += 1
        self.failure_count += 1
        log_warning(f"{self.logger_prefix} ✗ Failed to apply to {job_title}: {reason}")

    def get_stats(self) -> Dict:
        """Get platform statistics."""
        elapsed = (datetime.now() - self.start_time).total_seconds()
        success_rate = (
            (self.success_count / self.applications_count * 100)
            if self.applications_count > 0
            else 0
        )

        return {
            'platform': self.PLATFORM_NAME,
            'applications': self.applications_count,
            'success': self.success_count,
            'failures': self.failure_count,
            'success_rate': success_rate,
            'elapsed_seconds': elapsed,
        }

    def __repr__(self) -> str:
        """String representation."""
        stats = self.get_stats()
        return (
            f"{self.__class__.__name__}("
            f"applications={stats['applications']}, "
            f"success={stats['success']}, "
            f"rate={stats['success_rate']:.1f}%"
            f")"
        )
