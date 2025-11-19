"""
CAPTCHA detection module for identifying CAPTCHA challenges on web pages.

Detects CAPTCHA by analyzing page source, URLs, and element presence.
"""

import re
from typing import Tuple
from selenium.webdriver.common.by import By
from selenium.webdriver.remote.webdriver import WebDriver
from selenium.webdriver.support.ui import WebDriverWait
from selenium.webdriver.support import expected_conditions as EC

from utils.logger import log_debug, log_info


CAPTCHA_KEYWORDS = [
    "recaptcha",
    "hcaptcha",
    "captcha",
    "verify you are human",
    "prove you are not a robot",
    "please solve the captcha",
    "challenge verification",
    "security challenge",
    "reCAPTCHA",
    "hCaptcha",
    "cloudflare challenge",
    "turnstile",
]

CAPTCHA_PATTERNS = [
    r"recaptcha",
    r"hcaptcha",
    r"captcha",
    r"verify_human",
    r"challenge",
    r"__cf_chl",
    r"turnstile",
]

CAPTCHA_SELECTORS = [
    "[class*='recaptcha']",
    "[id*='recaptcha']",
    "[class*='hcaptcha']",
    "[id*='hcaptcha']",
    "[class*='captcha']",
    "[id*='captcha']",
    ".cf-challenge",
    "[data-captcha-type]",
    "iframe[src*='recaptcha']",
    "iframe[src*='hcaptcha']",
    "iframe[src*='captcha']",
]


def detect_captcha(
    driver: WebDriver,
    timeout: int = 5,
    check_page_source: bool = True,
    check_url: bool = True,
    check_elements: bool = True,
) -> Tuple[bool, float]:
    """
    Detect presence of CAPTCHA on the current page.

    Checks page source for CAPTCHA keywords, URL for CAPTCHA paths,
    and DOM for CAPTCHA elements.

    Args:
        driver: Selenium WebDriver instance.
        timeout: Timeout in seconds for DOM checks (default: 5).
        check_page_source: Check page source for CAPTCHA keywords (default: True).
        check_url: Check URL for CAPTCHA patterns (default: True).
        check_elements: Check DOM for CAPTCHA elements (default: True).

    Returns:
        Tuple of (captcha_detected, confidence_score).
        - captcha_detected: True if CAPTCHA detected, False otherwise.
        - confidence_score: Float between 0.0 and 1.0 indicating confidence.
    """
    confidence_score = 0.0
    detections: int = 0
    total_checks: int = 0

    try:
        current_url = driver.current_url.lower()
        current_title = driver.title.lower()

        if check_page_source:
            page_source = driver.page_source.lower()
            total_checks += 1

            keyword_matches = sum(
                1 for keyword in CAPTCHA_KEYWORDS if keyword in page_source
            )

            if keyword_matches > 0:
                detections += 1
                confidence_score += 0.4 * min(keyword_matches / 3, 1.0)
                log_debug(f"CAPTCHA keywords found in page source: {keyword_matches}")

            pattern_matches = sum(
                1 for pattern in CAPTCHA_PATTERNS if re.search(pattern, page_source, re.IGNORECASE)
            )

            if pattern_matches > 0:
                detections += 1
                confidence_score += 0.3 * min(pattern_matches / 3, 1.0)
                log_debug(f"CAPTCHA patterns found in page source: {pattern_matches}")

        if check_url:
            total_checks += 1

            if any(keyword in current_url for keyword in ["captcha", "challenge", "verify"]):
                detections += 1
                confidence_score += 0.3
                log_debug(f"CAPTCHA-related keywords found in URL: {current_url}")

            if any(keyword in current_title for keyword in ["verify", "challenge", "human"]):
                detections += 1
                confidence_score += 0.2
                log_debug(f"CAPTCHA-related title detected: {current_title}")

        if check_elements:
            total_checks += 1

            try:
                wait = WebDriverWait(driver, timeout)

                for selector in CAPTCHA_SELECTORS:
                    try:
                        elements = wait.until(
                            EC.presence_of_all_elements_located((By.CSS_SELECTOR, selector)),
                            timeout=1,
                        )

                        if elements:
                            detections += 1
                            confidence_score += 0.4
                            log_debug(f"CAPTCHA element found with selector: {selector}")
                            break

                    except Exception:
                        continue

            except Exception as e:
                log_debug(f"Error checking for CAPTCHA elements: {e}")

        if detections > 0 or confidence_score > 0.3:
            log_info(
                f"CAPTCHA detected with confidence {confidence_score:.2f} "
                f"({detections} detection(s))"
            )
            return True, min(confidence_score, 1.0)

        return False, 0.0

    except Exception as e:
        log_debug(f"Error during CAPTCHA detection: {e}")
        return False, 0.0
