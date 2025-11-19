"""
Indeed platform automation implementation.

Handles login, job search, and application submission on Indeed.com
"""

from typing import Dict, List, Optional
from selenium.webdriver.common.by import By
from selenium.webdriver.common.keys import Keys
from selenium.webdriver.remote.webdriver import WebDriver

from platforms.base_platform import AbstractBasePlatform
from utils.logger import log_info, log_error, log_debug, log_warning


class IndeedPlatform(AbstractBasePlatform):
    """Indeed.com job application automation."""

    PLATFORM_NAME = "indeed"
    PLATFORM_URL = "https://www.indeed.com"

    # CSS Selectors
    LOGIN_EMAIL_SELECTOR = "#ifl-inputEmail"
    LOGIN_PASSWORD_SELECTOR = "#ifl-inputPassword"
    LOGIN_BUTTON_SELECTOR = "#ifl-showPassword ~ button"
    SEARCH_INPUT_SELECTOR = ".desktop-searchbox #text-input-what"
    LOCATION_INPUT_SELECTOR = ".desktop-searchbox #text-input-where"
    SEARCH_BUTTON_SELECTOR = '.desktop-searchbox button[type="submit"]'

    JOB_LISTING_SELECTOR = ".job-search-results .resultWithShelfPadding"
    JOB_TITLE_SELECTOR = "h2 a span"
    JOB_COMPANY_SELECTOR = "[data-company-name]"
    APPLY_BUTTON_SELECTOR = "button[aria-label*='Apply']"
    EASY_APPLY_SELECTOR = ".ia-continueButton"
    NEXT_BUTTON_SELECTOR = 'button[data-testid="continueButton"]'
    SUBMIT_BUTTON_SELECTOR = 'button[data-testid="submitButton"]'

    LOGGED_IN_INDICATOR = ".userMenuButton"

    def __init__(self, driver: WebDriver, config: Dict):
        """Initialize Indeed platform."""
        super().__init__(driver, config)
        self.job_list = []
        self.current_job_index = 0

    def login(self, email: str, password: str) -> bool:
        """
        Login to Indeed with email and password.

        Args:
            email: Indeed email address
            password: Indeed password

        Returns:
            True if login successful
        """
        log_info(f"{self.logger_prefix} Attempting login...")

        try:
            # Navigate to Indeed
            if not self.navigate_to(self.PLATFORM_URL):
                return False

            # Click sign in
            sign_in_button = self.find_element("a[href*='signin']")
            if sign_in_button:
                self.safe_click(sign_in_button)
                self._random_delay(self.MEDIUM_DELAY, self.LONG_DELAY)
            else:
                log_warning(f"{self.logger_prefix} Sign in button not found")

            # Enter email
            email_field = self.wait_for_element(self.LOGIN_EMAIL_SELECTOR)
            if not email_field:
                log_error(f"{self.logger_prefix} Email field not found")
                return False

            if not self.safe_send_keys(email_field, email):
                return False

            self._random_delay(self.MEDIUM_DELAY)

            # Enter password
            password_field = self.wait_for_element(self.LOGIN_PASSWORD_SELECTOR)
            if not password_field:
                log_error(f"{self.logger_prefix} Password field not found")
                return False

            if not self.safe_send_keys(password_field, password):
                return False

            self._random_delay(self.MEDIUM_DELAY)

            # Click login button
            login_button = self.wait_for_element_clickable(self.LOGIN_BUTTON_SELECTOR)
            if not login_button:
                # Try alternative login button
                login_button = self.find_element('button[type="submit"]')

            if not login_button:
                log_error(f"{self.logger_prefix} Login button not found")
                return False

            self.safe_click(login_button)
            self._random_delay(self.LONG_DELAY, self.LONG_DELAY * 2)

            # Verify login
            if self.is_logged_in(self.LOGGED_IN_INDICATOR):
                log_info(f"{self.logger_prefix} ✓ Login successful")
                return True
            else:
                log_error(f"{self.logger_prefix} Login verification failed")
                return False

        except Exception as e:
            log_error(f"{self.logger_prefix} Login error: {e}")
            self.take_screenshot("login_error")
            return False

    def search_jobs(self, keywords: str, location: str = "") -> List[Dict]:
        """
        Search for jobs on Indeed.

        Args:
            keywords: Job search keywords
            location: Job location (optional)

        Returns:
            List of job dictionaries
        """
        log_info(f"{self.logger_prefix} Searching for jobs: {keywords}")

        try:
            # Navigate to indeed job search
            self.navigate_to(self.PLATFORM_URL + "/jobs")
            self._random_delay(self.MEDIUM_DELAY)

            # Fill search fields
            search_field = self.wait_for_element(self.SEARCH_INPUT_SELECTOR)
            if search_field:
                self.safe_send_keys(search_field, keywords)
                self._random_delay(self.SHORT_DELAY)

            if location:
                location_field = self.wait_for_element(self.LOCATION_INPUT_SELECTOR)
                if location_field:
                    self.safe_send_keys(location_field, location)
                    self._random_delay(self.SHORT_DELAY)

            # Click search button
            search_button = self.wait_for_element_clickable(self.SEARCH_BUTTON_SELECTOR)
            if search_button:
                self.safe_click(search_button)
                self._random_delay(self.LONG_DELAY, self.LONG_DELAY * 1.5)

            # Get job listings
            job_elements = self.find_elements(self.JOB_LISTING_SELECTOR)
            log_info(f"{self.logger_prefix} Found {len(job_elements)} job listings")

            # Extract job info
            jobs = []
            for idx, job_elem in enumerate(job_elements[:50]):  # Limit to 50
                try:
                    title_elem = job_elem.find_element(By.CSS_SELECTOR, self.JOB_TITLE_SELECTOR)
                    title = title_elem.text.strip() if title_elem else "Unknown"

                    company_elem = job_elem.find_element(By.CSS_SELECTOR, self.JOB_COMPANY_SELECTOR)
                    company = company_elem.get_attribute("data-company-name") or "Unknown"

                    # Get job link
                    link_elem = job_elem.find_element(By.CSS_SELECTOR, "a")
                    job_url = link_elem.get_attribute("href") or ""

                    if title and company:
                        jobs.append({
                            'title': title,
                            'company': company,
                            'url': job_url,
                            'platform': self.PLATFORM_NAME,
                            'element': job_elem,
                        })

                        log_debug(f"{self.logger_prefix} Job {idx+1}: {title} at {company}")

                except Exception as e:
                    log_debug(f"{self.logger_prefix} Error extracting job info: {e}")
                    continue

            self.job_list = jobs
            return jobs

        except Exception as e:
            log_error(f"{self.logger_prefix} Search error: {e}")
            self.take_screenshot("search_error")
            return []

    def apply_to_job(self, job: Dict, profile: Dict) -> bool:
        """
        Apply to a job on Indeed.

        Args:
            job: Job dictionary with title, company, url
            profile: User profile with personal info

        Returns:
            True if application successful
        """
        log_info(f"{self.logger_prefix} Applying to: {job.get('title')} at {job.get('company')}")

        try:
            # Navigate to job
            job_url = job.get('url')
            if not job_url:
                self.record_failure(job.get('title'), "No job URL")
                return False

            if not self.navigate_to(job_url):
                self.record_failure(job.get('title'), "Failed to navigate")
                return False

            self._random_delay(self.MEDIUM_DELAY, self.LONG_DELAY)

            # Look for Easy Apply button
            apply_button = self.wait_for_element_clickable(self.APPLY_BUTTON_SELECTOR)
            if not apply_button:
                log_warning(f"{self.logger_prefix} Apply button not found")
                self.record_failure(job.get('title'), "No apply button")
                return False

            # Click apply button
            if not self.safe_click(apply_button):
                self.record_failure(job.get('title'), "Failed to click apply")
                return False

            self._random_delay(self.MEDIUM_DELAY)

            # Handle Easy Apply form (if present)
            if not self._handle_easy_apply_form(profile):
                log_warning(f"{self.logger_prefix} Easy Apply form handling failed")
                # Don't fail - form might not be required

            self._random_delay(self.MEDIUM_DELAY, self.LONG_DELAY)

            # Submit application
            submit_button = self.find_element(self.SUBMIT_BUTTON_SELECTOR)
            if submit_button:
                if self.safe_click(submit_button):
                    self._random_delay(self.LONG_DELAY)
                    self.record_success(job.get('title'))
                    return True

            # Alternative: Check if application was submitted
            if "application" in self.driver.page_source.lower():
                self.record_success(job.get('title'))
                return True

            self.record_failure(job.get('title'), "Submit button not found")
            return False

        except Exception as e:
            log_error(f"{self.logger_prefix} Application error: {e}")
            self.record_failure(job.get('title'), str(e))
            self.take_screenshot("apply_error")
            return False

    def _handle_easy_apply_form(self, profile: Dict) -> bool:
        """
        Handle Easy Apply form submission.

        Args:
            profile: User profile

        Returns:
            True if form handled successfully
        """
        try:
            # Check for form fields
            form_fields = self.find_elements("input[type='text'], textarea, select")

            if not form_fields:
                log_debug(f"{self.logger_prefix} No form fields found")
                return True

            log_info(f"{self.logger_prefix} Found {len(form_fields)} form fields")

            # Fill visible form fields
            for field in form_fields:
                try:
                    placeholder = field.get_attribute("placeholder") or ""
                    name = field.get_attribute("name") or ""

                    # Match field to profile data
                    if "email" in placeholder.lower() or "email" in name.lower():
                        self.safe_send_keys(field, profile.get('email', ''))
                        self._random_delay(self.SHORT_DELAY)

                    elif "phone" in placeholder.lower() or "phone" in name.lower():
                        self.safe_send_keys(field, profile.get('phone', ''))
                        self._random_delay(self.SHORT_DELAY)

                    elif "name" in placeholder.lower() or "name" in name.lower():
                        self.safe_send_keys(field, profile.get('name', ''))
                        self._random_delay(self.SHORT_DELAY)

                except Exception as e:
                    log_debug(f"{self.logger_prefix} Error filling form field: {e}")
                    continue

            # Click next buttons
            for _ in range(5):  # Max 5 pages
                next_button = self.find_element(self.NEXT_BUTTON_SELECTOR)
                if next_button:
                    self.safe_click(next_button)
                    self._random_delay(self.MEDIUM_DELAY)
                else:
                    break

            return True

        except Exception as e:
            log_warning(f"{self.logger_prefix} Form handling error: {e}")
            return False
