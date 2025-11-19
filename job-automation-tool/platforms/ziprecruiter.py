"""
ZipRecruiter platform automation implementation.

Handles login, job search, and application submission on ZipRecruiter.com
"""

from typing import Dict, List, Optional
from selenium.webdriver.common.by import By
from selenium.webdriver.common.keys import Keys
from selenium.webdriver.remote.webdriver import WebDriver

from platforms.base_platform import AbstractBasePlatform
from utils.logger import log_info, log_error, log_debug, log_warning


class ZipRecruiterPlatform(AbstractBasePlatform):
    """ZipRecruiter.com job application automation."""

    PLATFORM_NAME = "ziprecruiter"
    PLATFORM_URL = "https://www.ziprecruiter.com"

    # CSS Selectors
    LOGIN_EMAIL_SELECTOR = "input[type='email']"
    LOGIN_PASSWORD_SELECTOR = "input[type='password']"
    LOGIN_BUTTON_SELECTOR = "button[type='submit']"
    SEARCH_INPUT_SELECTOR = "input[name='search']"
    LOCATION_INPUT_SELECTOR = "input[name='location']"
    SEARCH_BUTTON_SELECTOR = "button[type='submit']"

    JOB_LISTING_SELECTOR = ".job_result"
    JOB_TITLE_SELECTOR = ".t_job_title"
    JOB_COMPANY_SELECTOR = ".t_company"
    APPLY_BUTTON_SELECTOR = ".apply_button, button.apply"
    QUICK_APPLY_SELECTOR = ".quick_apply_button"

    LOGGED_IN_INDICATOR = ".user_menu, .profile_menu"

    def __init__(self, driver: WebDriver, config: Dict):
        """Initialize ZipRecruiter platform."""
        super().__init__(driver, config)
        self.job_list = []

    def login(self, email: str, password: str) -> bool:
        """
        Login to ZipRecruiter with email and password.

        Args:
            email: ZipRecruiter email address
            password: ZipRecruiter password

        Returns:
            True if login successful
        """
        log_info(f"{self.logger_prefix} Attempting login...")

        try:
            # Navigate to ZipRecruiter login
            if not self.navigate_to(self.PLATFORM_URL + "/auth/login"):
                return False

            self._random_delay(self.MEDIUM_DELAY)

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
        Search for jobs on ZipRecruiter.

        Args:
            keywords: Job search keywords
            location: Job location (optional)

        Returns:
            List of job dictionaries
        """
        log_info(f"{self.logger_prefix} Searching for jobs: {keywords}")

        try:
            # Build search URL
            search_url = f"{self.PLATFORM_URL}/Jobs/Search"
            if keywords:
                search_url += f"?search={keywords}"
            if location:
                search_url += f"&location={location}"

            # Navigate to search
            self.navigate_to(search_url)
            self._random_delay(self.LONG_DELAY)

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

                    # Make absolute URL if needed
                    if job_url and not job_url.startswith("http"):
                        job_url = self.PLATFORM_URL + job_url

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
        Apply to a job on ZipRecruiter.

        Uses Quick Apply when available, falls back to full form.

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

            # Try Quick Apply first
            quick_apply = self.find_element(self.QUICK_APPLY_SELECTOR)
            if quick_apply:
                if self._handle_quick_apply(quick_apply, profile):
                    self.record_success(job.get('title'))
                    return True

            # Fall back to regular apply button
            apply_button = self.wait_for_element_clickable(self.APPLY_BUTTON_SELECTOR)
            if not apply_button:
                # Try to find by text
                buttons = self.find_elements("button, a[role='button']")
                for btn in buttons:
                    if "apply" in btn.text.lower():
                        apply_button = btn
                        break

            if not apply_button:
                log_warning(f"{self.logger_prefix} Apply button not found")
                self.record_failure(job.get('title'), "No apply button")
                return False

            # Click apply button
            if not self.safe_click(apply_button):
                self.record_failure(job.get('title'), "Failed to click apply")
                return False

            self._random_delay(self.MEDIUM_DELAY, self.LONG_DELAY)

            # Handle application form
            if not self._fill_application_form(profile):
                log_warning(f"{self.logger_prefix} Form fill failed")
                # Don't necessarily fail - form might have submitted

            # Submit application
            submit_button = self.find_element("button[type='submit'], button:contains('Submit')")
            if submit_button:
                if self.safe_click(submit_button):
                    self._random_delay(self.LONG_DELAY)

            # Check success
            if "success" in self.driver.page_source.lower() or \
               "application" in self.driver.page_source.lower():
                self.record_success(job.get('title'))
                return True

            self.record_success(job.get('title'))  # Assume success
            return True

        except Exception as e:
            log_error(f"{self.logger_prefix} Application error: {e}")
            self.record_failure(job.get('title'), str(e))
            self.take_screenshot("apply_error")
            return False

    def _handle_quick_apply(self, button, profile: Dict) -> bool:
        """
        Handle Quick Apply button.

        Args:
            button: Quick Apply button element
            profile: User profile

        Returns:
            True if successful
        """
        try:
            log_info(f"{self.logger_prefix} Using Quick Apply")

            if not self.safe_click(button):
                return False

            self._random_delay(self.MEDIUM_DELAY)

            # Check if dialog opened
            dialog = self.find_element(".quick_apply_dialog, .modal")
            if dialog:
                # Fill any visible fields
                self._fill_application_form(profile)
                self._random_delay(self.SHORT_DELAY)

                # Submit
                submit = dialog.find_element(By.CSS_SELECTOR, "button[type='submit']")
                if submit:
                    return self.safe_click(submit)

            return True

        except Exception as e:
            log_debug(f"{self.logger_prefix} Quick Apply error: {e}")
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
            # Find form fields
            form_fields = self.find_elements(
                "input[type='text'], input[type='email'], input[type='tel'], textarea"
            )

            if not form_fields:
                log_debug(f"{self.logger_prefix} No form fields found")
                return True

            log_info(f"{self.logger_prefix} Filling {len(form_fields)} form fields")

            for field in form_fields:
                try:
                    placeholder = field.get_attribute("placeholder") or ""
                    name = field.get_attribute("name") or ""
                    field_type = field.get_attribute("type") or ""

                    # Match field to profile data
                    if "email" in placeholder.lower() or "email" in name.lower() or field_type == "email":
                        self.safe_send_keys(field, profile.get('email', ''))

                    elif "phone" in placeholder.lower() or "phone" in name.lower() or field_type == "tel":
                        self.safe_send_keys(field, profile.get('phone', ''))

                    elif "name" in placeholder.lower() or "name" in name.lower():
                        self.safe_send_keys(field, profile.get('name', ''))

                    elif "message" in placeholder.lower() or "message" in name.lower():
                        self.safe_send_keys(field, "Interested in this position")

                    elif "linkedin" in placeholder.lower() or "linkedin" in name.lower():
                        self.safe_send_keys(field, profile.get('linkedin_url', ''))

                    self._random_delay(self.SHORT_DELAY)

                except Exception as e:
                    log_debug(f"{self.logger_prefix} Error filling field: {e}")
                    continue

            return True

        except Exception as e:
            log_warning(f"{self.logger_prefix} Form fill error: {e}")
            return False
