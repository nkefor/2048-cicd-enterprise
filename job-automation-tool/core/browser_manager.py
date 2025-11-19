"""
Browser management module with anti-detection and human-like behavior.

Handles Selenium WebDriver creation, stealth configuration, and human-like interaction patterns.
"""

import time
import random
from pathlib import Path
from typing import Optional, List, Dict, Tuple
from datetime import datetime

from selenium import webdriver
from selenium.webdriver.common.by import By
from selenium.webdriver.common.action_chains import ActionChains
from selenium.webdriver.support.ui import WebDriverWait
from selenium.webdriver.support import expected_conditions as EC
from selenium.webdriver.remote.webdriver import WebDriver
from selenium.common.exceptions import (
    TimeoutException,
    WebDriverException,
    StaleElementReferenceException,
)

from utils.logger import log_info, log_error, log_debug, log_warning


class BrowserManager:
    """Manage Selenium WebDriver with anti-detection and human-like behavior."""

    USER_AGENTS = [
        "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36",
        "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36",
        "Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36",
        "Mozilla/5.0 (Windows NT 10.0; Win64; x64; rv:121.0) Gecko/20100101 Firefox/121.0",
        "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.1 Safari/605.1.15",
    ]

    VIEWPORT_SIZES = [
        (1920, 1080),
        (1366, 768),
        (1440, 900),
        (1600, 900),
        (2560, 1440),
    ]

    def __init__(
        self,
        headless: bool = False,
        timeout: int = 30,
        screenshot_dir: str = "screenshots",
    ):
        """
        Initialize BrowserManager.

        Args:
            headless: Run browser in headless mode (default: False).
            timeout: Default timeout for element waits (default: 30 seconds).
            screenshot_dir: Directory to save error screenshots (default: 'screenshots').
        """
        self.headless = headless
        self.timeout = timeout
        self.screenshot_dir = Path(screenshot_dir)
        self.screenshot_dir.mkdir(parents=True, exist_ok=True)

        self.driver: Optional[WebDriver] = None
        self.cookies: Dict[str, str] = {}

        log_debug(f"BrowserManager initialized: headless={headless}, timeout={timeout}")

    def create_driver(self) -> WebDriver:
        """
        Create and configure Selenium WebDriver with anti-detection measures.

        Returns:
            Configured WebDriver instance.

        Raises:
            WebDriverException: If driver creation fails.
        """
        if self.driver is not None:
            log_warning("Driver already exists, closing old instance")
            self.quit()

        try:
            options = webdriver.ChromeOptions()

            options.add_argument(f"user-agent={self._get_random_user_agent()}")

            viewport_width, viewport_height = self._get_random_viewport()
            options.add_argument(f"--window-size={viewport_width},{viewport_height}")

            if self.headless:
                options.add_argument("--headless=new")

            options.add_argument("--no-sandbox")
            options.add_argument("--disable-dev-shm-usage")
            options.add_argument("--disable-blink-features=AutomationControlled")
            options.add_argument("--disable-extensions")
            options.add_argument("--disable-plugins")
            options.add_argument("--disable-images")
            options.add_argument("--disable-notifications")
            options.add_argument("--disable-media-session-api")

            options.add_experimental_option("excludeSwitches", ["enable-automation"])
            options.add_experimental_option("useAutomationExtension", False)

            self.driver = webdriver.Chrome(options=options)

            self._inject_stealth_scripts()

            log_info("WebDriver created successfully with anti-detection measures")
            return self.driver

        except WebDriverException as e:
            log_error(f"Failed to create WebDriver: {e}")
            raise

        except Exception as e:
            log_error(f"Unexpected error creating WebDriver: {e}")
            raise

    def _get_random_user_agent(self) -> str:
        """Get random user agent from list."""
        return random.choice(self.USER_AGENTS)

    def _get_random_viewport(self) -> Tuple[int, int]:
        """Get random viewport size from list."""
        return random.choice(self.VIEWPORT_SIZES)

    def _inject_stealth_scripts(self) -> None:
        """Inject JavaScript to prevent detection as automated browser."""
        if self.driver is None:
            return

        stealth_js = """
        Object.defineProperty(navigator, 'webdriver', {
            get: () => false,
        });
        Object.defineProperty(navigator, 'plugins', {
            get: () => [1, 2, 3, 4, 5],
        });
        Object.defineProperty(navigator, 'languages', {
            get: () => ['en-US', 'en'],
        });
        Object.defineProperty(navigator, 'permissions', {
            get: () => ({
                query: () => Promise.resolve({ state: Notification.permission }),
            }),
        });
        """

        try:
            self.driver.execute_script(stealth_js)
            log_debug("Stealth scripts injected")
        except Exception as e:
            log_warning(f"Failed to inject stealth scripts: {e}")

    def create_stealth_driver(self) -> WebDriver:
        """
        Create stealth driver with all anti-detection measures.

        This is an alias for create_driver() for compatibility.

        Returns:
            Configured WebDriver instance.
        """
        return self.create_driver()

    def navigate_to(self, url: str, wait_element: Optional[str] = None, wait_time: int = 10) -> bool:
        """
        Navigate to URL with human-like behavior.

        Args:
            url: URL to navigate to.
            wait_element: CSS selector to wait for after navigation.
            wait_time: Time to wait for element (default: 10 seconds).

        Returns:
            True if navigation successful, False otherwise.
        """
        if self.driver is None:
            log_error("Driver not initialized")
            return False

        try:
            self._random_delay(0.5, 2)
            self.driver.get(url)
            log_debug(f"Navigated to {url}")

            if wait_element:
                try:
                    WebDriverWait(self.driver, wait_time).until(
                        EC.presence_of_element_located((By.CSS_SELECTOR, wait_element))
                    )
                    log_debug(f"Wait element found: {wait_element}")
                except TimeoutException:
                    log_warning(f"Timeout waiting for element: {wait_element}")
                    return False

            return True

        except Exception as e:
            log_error(f"Navigation failed to {url}: {e}")
            self.take_screenshot("navigation_error")
            return False

    def human_click(self, element) -> bool:
        """
        Click element with human-like behavior.

        Moves mouse to element before clicking with random delay.

        Args:
            element: Selenium WebElement to click.

        Returns:
            True if click successful, False otherwise.
        """
        if self.driver is None:
            log_error("Driver not initialized")
            return False

        try:
            ActionChains(self.driver).move_to_element(element).perform()
            self._random_delay(0.1, 0.5)
            element.click()
            log_debug("Element clicked with human-like behavior")
            return True

        except StaleElementReferenceException:
            log_warning("Element became stale before clicking")
            return False

        except Exception as e:
            log_error(f"Human click failed: {e}")
            return False

    def human_send_keys(self, element, text: str, char_delay: float = 0.05) -> bool:
        """
        Send keys with human-like typing behavior.

        Args:
            element: Selenium WebElement to type in.
            text: Text to type.
            char_delay: Delay between characters in seconds (default: 0.05).

        Returns:
            True if successful, False otherwise.
        """
        if self.driver is None:
            log_error("Driver not initialized")
            return False

        try:
            ActionChains(self.driver).move_to_element(element).perform()
            self._random_delay(0.1, 0.5)

            for char in text:
                element.send_keys(char)
                self._random_delay(char_delay * 0.5, char_delay * 1.5)

            log_debug(f"Typed {len(text)} characters with human-like behavior")
            return True

        except Exception as e:
            log_error(f"Human send keys failed: {e}")
            return False

    def random_mouse_movement(self, iterations: int = 3) -> None:
        """
        Simulate random mouse movements.

        Args:
            iterations: Number of random movements (default: 3).
        """
        if self.driver is None:
            return

        try:
            actions = ActionChains(self.driver)

            for _ in range(iterations):
                x = random.randint(100, 1000)
                y = random.randint(100, 600)
                actions.move_by_offset(x, y)
                self._random_delay(0.1, 0.3)

            actions.perform()
            log_debug(f"Random mouse movements executed: {iterations} iterations")

        except Exception as e:
            log_debug(f"Random mouse movement failed: {e}")

    def scroll_page(self, direction: str = "down", amount: int = 3) -> None:
        """
        Scroll page with human-like behavior.

        Args:
            direction: Scroll direction ('up' or 'down', default: 'down').
            amount: Number of scroll iterations (default: 3).
        """
        if self.driver is None:
            return

        try:
            scroll_script = (
                f"window.scrollBy(0, {300 if direction.lower() == 'down' else -300})"
                if amount == 1
                else "window.scrollBy(0, 300)" if direction.lower() == "down"
                else "window.scrollBy(0, -300)"
            )

            for _ in range(amount):
                self.driver.execute_script(scroll_script)
                self._random_delay(0.5, 1.5)

            log_debug(f"Page scrolled: {direction} x {amount}")

        except Exception as e:
            log_debug(f"Scroll failed: {e}")

    def _random_delay(self, min_seconds: float, max_seconds: float) -> None:
        """
        Sleep for random duration to simulate human behavior.

        Args:
            min_seconds: Minimum delay in seconds.
            max_seconds: Maximum delay in seconds.
        """
        delay = random.uniform(min_seconds, max_seconds)
        time.sleep(delay)

    def add_cookie(self, name: str, value: str) -> bool:
        """
        Add cookie to driver.

        Args:
            name: Cookie name.
            value: Cookie value.

        Returns:
            True if successful, False otherwise.
        """
        if self.driver is None:
            log_error("Driver not initialized")
            return False

        try:
            self.driver.add_cookie({"name": name, "value": value})
            self.cookies[name] = value
            log_debug(f"Cookie added: {name}")
            return True

        except Exception as e:
            log_error(f"Failed to add cookie {name}: {e}")
            return False

    def load_cookies(self) -> bool:
        """
        Load saved cookies into driver.

        Returns:
            True if cookies loaded, False otherwise.
        """
        if self.driver is None:
            log_error("Driver not initialized")
            return False

        try:
            for name, value in self.cookies.items():
                self.driver.add_cookie({"name": name, "value": value})

            log_info(f"Loaded {len(self.cookies)} cookies")
            return True

        except Exception as e:
            log_error(f"Failed to load cookies: {e}")
            return False

    def clear_cookies(self) -> None:
        """Clear all cookies from driver and storage."""
        if self.driver is None:
            return

        try:
            self.driver.delete_all_cookies()
            self.cookies.clear()
            log_debug("Cookies cleared")

        except Exception as e:
            log_warning(f"Failed to clear cookies: {e}")

    def take_screenshot(self, name: str = "screenshot") -> Optional[Path]:
        """
        Take screenshot and save to file.

        Args:
            name: Name for screenshot file (without extension).

        Returns:
            Path to screenshot file or None if failed.
        """
        if self.driver is None:
            log_error("Driver not initialized")
            return None

        try:
            timestamp = datetime.now().strftime("%Y%m%d_%H%M%S")
            filename = self.screenshot_dir / f"{name}_{timestamp}.png"

            self.driver.save_screenshot(str(filename))
            log_info(f"Screenshot saved: {filename}")
            return filename

        except Exception as e:
            log_error(f"Failed to take screenshot: {e}")
            return None

    def get_page_source(self) -> Optional[str]:
        """
        Get page source HTML.

        Returns:
            Page source or None if failed.
        """
        if self.driver is None:
            log_error("Driver not initialized")
            return None

        try:
            return self.driver.page_source

        except Exception as e:
            log_error(f"Failed to get page source: {e}")
            return None

    def execute_script(self, script: str, *args) -> Optional[any]:
        """
        Execute JavaScript in driver.

        Args:
            script: JavaScript code to execute.
            *args: Arguments to pass to script.

        Returns:
            Script result or None if failed.
        """
        if self.driver is None:
            log_error("Driver not initialized")
            return None

        try:
            return self.driver.execute_script(script, *args)

        except Exception as e:
            log_error(f"Failed to execute script: {e}")
            return None

    def wait_for_element(
        self, selector: str, timeout: Optional[int] = None
    ) -> Optional[any]:
        """
        Wait for element to be present on page.

        Args:
            selector: CSS selector for element.
            timeout: Timeout in seconds (default: self.timeout).

        Returns:
            WebElement or None if timeout.
        """
        if self.driver is None:
            log_error("Driver not initialized")
            return None

        timeout = timeout or self.timeout

        try:
            element = WebDriverWait(self.driver, timeout).until(
                EC.presence_of_element_located((By.CSS_SELECTOR, selector))
            )
            log_debug(f"Element found: {selector}")
            return element

        except TimeoutException:
            log_warning(f"Timeout waiting for element: {selector}")
            return None

        except Exception as e:
            log_error(f"Error waiting for element {selector}: {e}")
            return None

    def quit(self) -> None:
        """Close WebDriver and cleanup."""
        if self.driver is not None:
            try:
                self.driver.quit()
                log_info("WebDriver closed")

            except Exception as e:
                log_warning(f"Error closing WebDriver: {e}")

            finally:
                self.driver = None

    def __enter__(self):
        """Context manager entry."""
        self.create_driver()
        return self

    def __exit__(self, exc_type, exc_val, exc_tb):
        """Context manager exit."""
        self.quit()
        if exc_type is not None:
            log_error(f"Exception in context manager: {exc_val}")
        return False
