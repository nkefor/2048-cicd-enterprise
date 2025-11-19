"""
Dice platform automation implementation.

Handles login, job search, and application submission on Dice.com
"""

from typing import Dict, List, Optional
from selenium.webdriver.common.by import By
from selenium.webdriver.common.keys import Keys
from selenium.webdriver.remote.webdriver import WebDriver

from platforms.base_platform import AbstractBasePlatform
from utils.logger import log_info, log_error, log_debug, log_warning


class DicePlatform(AbstractBasePlatform):
    """Dice.com job application automation."""

    PLATFORM_NAME = "dice"
    PLATFORM_URL = "https://www.dice.com"

    # CSS Selectors
    LOGIN_EMAIL_SELECTOR = "input[type='email']"
    LOGIN_PASSWORD_SELECTOR = "input[type='password']"
    LOGIN_BUTTON_SELECTOR = "button[data-test-id='login-button']"
    SEARCH_INPUT_SELECTOR = "input[data-test-id='search-keyword']"
    LOCATION_INPUT_SELECTOR = "input[data-test-id='search-location']"
    SEARCH_BUTTON_SELECTOR = "button[data-test-id='search-submit-btn']"

    JOB_LISTING_SELECTOR = "[data-test-id='job-card']"
    JOB_TITLE_SELECTOR = "h3"
    JOB_COMPANY_SELECTOR = "[data-test-id='company-name']"
    APPLY_BUTTON_SELECTOR = "button[data-test-id='apply-button']"
    SUBMIT_APPLICATION_SELECTOR = "button[data-test-id='submit-application']"

    LOGGED_IN_INDICATOR = "[data-test-id='profile-menu']"

    def __init__(self, driver: WebDriver, config: Dict):
        """Initialize Dice platform."""
        super().__init__(driver, config)
        self.job_list = []

    def login(self, email: str, password: str) -> bool:
        """
        Login to Dice with email and password.

        Args:
            email: Dice email address
            password: Dice password

        Returns:
            True if login successful
        """
        log_info(f"{self.logger_prefix} Attempting login...")

        try:
            # Navigate to Dice
            if not self.navigate_to(self.PLATFORM_URL):
                return False

            # Click sign in
            sign_in_link = self.find_element("a[href*='login'], a[href*='signin']")
            if sign_in_link:
                self.safe_click(sign_in_link)
                self._random_delay(self.MEDIUM_DELAY, self.LONG_DELAY)
            else:
                log_debug(f"{self.logger_prefix} Sign in link not found, trying direct navigation")
                self.navigate_to(self.PLATFORM_URL + "/login")

            # Enter email
            email_field = self.wait_for_element(self.LOGIN_EMAIL_SELECTOR)
            if not email_field:
                log_error(f"{self.logger_prefix} Email field not found")
                self.take_screenshot("login_email_error")
                return False

            if not self.safe_send_keys(email_field, email):
                return False

            self._random_delay(self.MEDIUM_DELAY)

            # Enter password
            password_field = self.wait_for_element(self.LOGIN_PASSWORD_SELECTOR)
            if not password_field:
                log_error(f"{self.logger_prefix} Password field not found")
                self.take_screenshot("login_password_error")
                return False

            if not self.safe_send_keys(password_field, password):
                return False

            self._random_delay(self.MEDIUM_DELAY)

            # Click login button
            login_button = self.wait_for_element_clickable(self.LOGIN_BUTTON_SELECTOR)
            if not login_button:
                login_button = self.find_element("button[type='submit']")

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
                log_warning(f"{self.logger_prefix} Login verification failed")
                self.take_screenshot("login_verify_error")
                return False

        except Exception as e:
            log_error(f"{self.logger_prefix} Login error: {e}")
            self.take_screenshot("login_error")
            return False

    def search_jobs(self, keywords: str, location: str = "") -> List[Dict]:
        """
        Search for jobs on Dice.

        Args:
            keywords: Job search keywords
            location: Job location (optional)

        Returns:
            List of job dictionaries
        """
        log_info(f"{self.logger_prefix} Searching for jobs: {keywords}")

        try:
            # Navigate to Dice jobs
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
            else:
                log_warning(f"{self.logger_prefix} Search button not found")

            # Get job listings
            job_elements = self.find_elements(self.JOB_LISTING_SELECTOR)
            log_info(f"{self.logger_prefix} Found {len(job_elements)} job listings")

            # Extract job info
            jobs = []
            for idx, job_elem in enumerate(job_elements[:50]):  # Limit to 50
                try:
                    # Get title
                    title_elem = job_elem.find_element(By.CSS_SELECTOR, self.JOB_TITLE_SELECTOR)
                    title = title_elem.text.strip() if title_elem else "Unknown"

                    # Get company
                    try:
                        company_elem = job_elem.find_element(By.CSS_SELECTOR, self.JOB_COMPANY_SELECTOR)
                        company = company_elem.text.strip() if company_elem else "Unknown"
                    except:
                        company = "Unknown"

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
        Apply to a job on Dice.

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

            # Look for apply button
            apply_button = self.wait_for_element_clickable(self.APPLY_BUTTON_SELECTOR)
            if not apply_button:
                # Try alternative apply button
                apply_button = self.find_element("button:contains('Apply')")

            if not apply_button:
                log_warning(f"{self.logger_prefix} Apply button not found")
                # Try finding by text
                buttons = self.find_elements("button")
                for btn in buttons:
                    if "apply" in btn.text.lower():
                        apply_button = btn
                        break

            if not apply_button:
                self.record_failure(job.get('title'), "No apply button")
                return False

            # Click apply button
            if not self.safe_click(apply_button):
                self.record_failure(job.get('title'), "Failed to click apply")
                return False

            self._random_delay(self.MEDIUM_DELAY, self.LONG_DELAY)

            # Handle application form
            if not self._fill_application_form(profile):
                log_warning(f"{self.logger_prefix} Application form handling failed")

            # Submit application
            submit_button = self.wait_for_element_clickable(self.SUBMIT_APPLICATION_SELECTOR)
            if not submit_button:
                # Try finding by text
                buttons = self.find_elements("button")
                for btn in buttons:
                    if "submit" in btn.text.lower() or "apply" in btn.text.lower():
                        submit_button = btn
                        break

            if submit_button:
                if self.safe_click(submit_button):
                    self._random_delay(self.LONG_DELAY)
                    self.record_success(job.get('title'))
                    return True
            else:
                log_warning(f"{self.logger_prefix} Submit button not found")

            # Check if application was sent
            if "success" in self.driver.page_source.lower() or \
               "application sent" in self.driver.page_source.lower():
                self.record_success(job.get('title'))
                return True

            self.record_failure(job.get('title'), "Submit failed")
            return False

        except Exception as e:
            log_error(f"{self.logger_prefix} Application error: {e}")
            self.record_failure(job.get('title'), str(e))
            self.take_screenshot("apply_error")
            return False

    def _fill_application_form(self, profile: Dict) -> bool:
        """
        Fill application form fields.

        Args:
            profile: User profile

        Returns:
            True if form filled successfully
        """
        try:
            # Find and fill form fields
            form_fields = self.find_elements("input[type='text'], input[type='email'], textarea")

            if not form_fields:
                log_debug(f"{self.logger_prefix} No form fields found")
                return True

            log_info(f"{self.logger_prefix} Found {len(form_fields)} form fields")

            for field in form_fields:
                try:
                    placeholder = field.get_attribute("placeholder") or ""
                    name = field.get_attribute("name") or ""
                    field_type = field.get_attribute("type") or ""

                    # Match field type to profile data
                    if "email" in placeholder.lower() or "email" in name.lower() or field_type == "email":
                        self.safe_send_keys(field, profile.get('email', ''))

                    elif "phone" in placeholder.lower() or "phone" in name.lower():
                        self.safe_send_keys(field, profile.get('phone', ''))

                    elif "name" in placeholder.lower() or "name" in name.lower():
                        self.safe_send_keys(field, profile.get('name', ''))

                    elif "message" in placeholder.lower() or "message" in name.lower():
                        self.safe_send_keys(field, "Interested in this position")

                    self._random_delay(self.SHORT_DELAY)

                except Exception as e:
                    log_debug(f"{self.logger_prefix} Error filling field: {e}")
                    continue

            return True

        except Exception as e:
            log_warning(f"{self.logger_prefix} Form fill error: {e}")
            return False
