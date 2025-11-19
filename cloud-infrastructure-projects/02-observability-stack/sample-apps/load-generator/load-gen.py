#!/usr/bin/env python3
"""
Load Generator for Observability Stack
Generates realistic traffic patterns to test monitoring, alerting, and tracing
"""

import json
import logging
import os
import random
import threading
import time
from datetime import datetime
from typing import List, Dict, Any

import requests
from pythonjsonlogger import jsonlogger

# ============================================================================
# Configuration
# ============================================================================

TARGET_URL = os.getenv("TARGET_URL", "http://localhost:8000")
REQUESTS_PER_SECOND = int(os.getenv("REQUESTS_PER_SECOND", "10"))
DURATION_SECONDS = int(os.getenv("DURATION_SECONDS", "3600"))
BURST_PROBABILITY = float(os.getenv("BURST_PROBABILITY", "0.05"))  # 5% chance of burst
MAX_BURST_MULTIPLIER = float(os.getenv("MAX_BURST_MULTIPLIER", "5.0"))
ERROR_INJECTION_RATE = float(os.getenv("ERROR_INJECTION_RATE", "0.02"))  # 2% error rate
LATENCY_INJECTION_RATE = float(os.getenv("LATENCY_INJECTION_RATE", "0.05"))  # 5% latency
MAX_LATENCY_DELAY = float(os.getenv("MAX_LATENCY_DELAY", "3.0"))  # 3 seconds

# ============================================================================
# Logging Setup
# ============================================================================

def setup_logging():
    """Configure structured JSON logging"""
    logger = logging.getLogger()
    logger.setLevel(logging.INFO)

    json_handler = logging.StreamHandler()
    json_formatter = jsonlogger.JsonFormatter(
        fmt='%(timestamp)s %(level)s %(name)s %(message)s',
        timestamp=True,
        rename_fields={'timestamp': '@timestamp'}
    )
    json_handler.setFormatter(json_formatter)
    logger.addHandler(json_handler)

    return logger

logger = setup_logging()

# ============================================================================
# Load Patterns
# ============================================================================

class LoadPattern:
    """Base class for load generation patterns"""

    def __init__(self, name: str):
        self.name = name
        self.request_count = 0
        self.error_count = 0
        self.start_time = time.time()

    def get_rps(self, elapsed_time: float) -> float:
        """Get requests per second for current time"""
        raise NotImplementedError

    def get_endpoint(self) -> str:
        """Get next endpoint to test"""
        raise NotImplementedError

    def get_payload(self) -> Dict[str, Any]:
        """Get request payload"""
        return {}

    def get_method(self) -> str:
        """Get HTTP method"""
        return "GET"

    def should_inject_error(self) -> bool:
        """Determine if request should error"""
        return random.random() < ERROR_INJECTION_RATE

    def should_inject_latency(self) -> bool:
        """Determine if request should have injected latency"""
        return random.random() < LATENCY_INJECTION_RATE

    def get_injected_delay(self) -> float:
        """Get injected latency delay in seconds"""
        return random.uniform(0.1, MAX_LATENCY_DELAY)

    def report_stats(self):
        """Report current statistics"""
        elapsed = time.time() - self.start_time
        actual_rps = self.request_count / elapsed if elapsed > 0 else 0
        error_rate = (self.error_count / self.request_count * 100) if self.request_count > 0 else 0

        logger.info(
            f"Load pattern {self.name} statistics",
            extra={
                "pattern": self.name,
                "total_requests": self.request_count,
                "total_errors": self.error_count,
                "error_rate_percent": error_rate,
                "actual_rps": round(actual_rps, 2),
                "elapsed_seconds": round(elapsed, 2)
            }
        )

class NormalLoadPattern(LoadPattern):
    """Normal steady load pattern"""

    def __init__(self, base_rps: float):
        super().__init__("normal")
        self.base_rps = base_rps
        self.endpoints = [
            "/items",
            "/items?skip=0&limit=5",
            "/items?skip=5&limit=5",
            "/health",
            "/info"
        ]

    def get_rps(self, elapsed_time: float) -> float:
        # Add random burst traffic
        if random.random() < BURST_PROBABILITY:
            return self.base_rps * random.uniform(1.0, MAX_BURST_MULTIPLIER)
        return self.base_rps

    def get_endpoint(self) -> str:
        return random.choice(self.endpoints)

class SpikeLoadPattern(LoadPattern):
    """Spike load pattern - sudden traffic increases"""

    def __init__(self, base_rps: float, spike_interval: float = 60):
        super().__init__("spike")
        self.base_rps = base_rps
        self.spike_interval = spike_interval
        self.last_spike_time = time.time()
        self.endpoints = [
            "/items",
            "/items?skip=0&limit=10",
            "/create",
        ]

    def get_rps(self, elapsed_time: float) -> float:
        current_time = time.time()
        time_since_spike = current_time - self.last_spike_time

        if time_since_spike > self.spike_interval:
            # Generate spike
            self.last_spike_time = current_time
            spike_rps = self.base_rps * 3
            logger.info("Traffic spike detected", extra={"spike_rps": spike_rps})
            return spike_rps

        return self.base_rps

    def get_endpoint(self) -> str:
        return random.choice(self.endpoints)

class SlowResponsePattern(LoadPattern):
    """Pattern that triggers slow response testing"""

    def __init__(self, base_rps: float):
        super().__init__("slow_response")
        self.base_rps = base_rps
        self.slow_probability = 0.1  # 10% of requests are slow

    def get_rps(self, elapsed_time: float) -> float:
        return self.base_rps

    def get_endpoint(self) -> str:
        if random.random() < self.slow_probability:
            return "/slow?duration=3"
        return "/items"

class ErrorPattern(LoadPattern):
    """Pattern that triggers error testing"""

    def __init__(self, base_rps: float):
        super().__init__("error")
        self.base_rps = base_rps
        self.error_probability = 0.1  # 10% of requests error

    def get_rps(self, elapsed_time: float) -> float:
        return self.base_rps

    def get_endpoint(self) -> str:
        if random.random() < self.error_probability:
            return "/error"
        return "/items"

    def should_inject_error(self) -> bool:
        return False  # Errors come from the /error endpoint

class CreateItemsPattern(LoadPattern):
    """Pattern for creating items"""

    def __init__(self, base_rps: float):
        super().__init__("create_items")
        self.base_rps = base_rps

    def get_rps(self, elapsed_time: float) -> float:
        return self.base_rps

    def get_endpoint(self) -> str:
        return "/items"

    def get_method(self) -> str:
        if random.random() < 0.3:  # 30% POST requests
            return "POST"
        return "GET"

    def get_payload(self) -> Dict[str, Any]:
        return {
            "name": f"Item-{random.randint(1000, 9999)}",
            "price": round(random.uniform(10, 1000), 2)
        }

# ============================================================================
# Load Generator
# ============================================================================

class LoadGenerator:
    """Main load generator"""

    def __init__(self, target_url: str, patterns: List[LoadPattern], duration: int):
        self.target_url = target_url
        self.patterns = patterns
        self.duration = duration
        self.running = False
        self.stats_thread = None
        self.request_thread = None
        self.total_requests = 0
        self.total_errors = 0

    def make_request(self, pattern: LoadPattern) -> bool:
        """Make a single HTTP request"""
        try:
            endpoint = pattern.get_endpoint()
            method = pattern.get_method()
            url = f"{self.target_url}{endpoint}"
            payload = pattern.get_payload()

            # Inject latency if needed
            if pattern.should_inject_latency():
                delay = pattern.get_injected_delay()
                time.sleep(delay)

            start_time = time.time()

            if method == "POST":
                response = requests.post(
                    url,
                    json=payload,
                    timeout=10,
                    headers={
                        "User-Agent": "LoadGenerator/1.0",
                        "X-Load-Pattern": pattern.name
                    }
                )
            else:
                response = requests.get(
                    url,
                    timeout=10,
                    headers={
                        "User-Agent": "LoadGenerator/1.0",
                        "X-Load-Pattern": pattern.name
                    }
                )

            elapsed = time.time() - start_time
            pattern.request_count += 1
            self.total_requests += 1

            # Check for errors
            if response.status_code >= 400:
                pattern.error_count += 1
                self.total_errors += 1
                logger.warning(
                    f"Request failed",
                    extra={
                        "url": url,
                        "method": method,
                        "status": response.status_code,
                        "elapsed_ms": round(elapsed * 1000, 2),
                        "pattern": pattern.name
                    }
                )
                return False
            else:
                logger.debug(
                    f"Request successful",
                    extra={
                        "url": url,
                        "method": method,
                        "status": response.status_code,
                        "elapsed_ms": round(elapsed * 1000, 2),
                        "pattern": pattern.name
                    }
                )
                return True

        except requests.exceptions.Timeout:
            pattern.error_count += 1
            self.total_errors += 1
            logger.error(f"Request timeout: {pattern.get_endpoint()}")
            return False
        except requests.exceptions.ConnectionError:
            pattern.error_count += 1
            self.total_errors += 1
            logger.error(f"Connection error: {self.target_url}")
            return False
        except Exception as e:
            pattern.error_count += 1
            self.total_errors += 1
            logger.error(f"Request failed: {str(e)}")
            return False

    def generate_load(self):
        """Main load generation loop"""
        logger.info(
            "Load generation started",
            extra={
                "target_url": self.target_url,
                "duration_seconds": self.duration,
                "patterns": [p.name for p in self.patterns]
            }
        )

        self.running = True
        start_time = time.time()
        pattern_index = 0
        request_queue = []

        while self.running:
            elapsed = time.time() - start_time

            if elapsed > self.duration:
                logger.info(
                    "Load generation duration reached",
                    extra={"elapsed_seconds": round(elapsed, 2)}
                )
                break

            # Rotate through patterns
            pattern = self.patterns[pattern_index % len(self.patterns)]
            target_rps = pattern.get_rps(elapsed)

            # Calculate requests needed for this second
            requests_this_second = max(1, int(target_rps))

            for _ in range(requests_this_second):
                if not self.running:
                    break

                # Make request
                self.make_request(pattern)

                # Sleep to maintain RPS
                sleep_time = 1.0 / max(target_rps, 1)
                time.sleep(sleep_time)

            pattern_index += 1

        self.running = False
        logger.info("Load generation completed")

    def report_stats(self):
        """Periodically report statistics"""
        while self.running:
            time.sleep(60)  # Report every 60 seconds

            logger.info(
                "Load generation statistics",
                extra={
                    "total_requests": self.total_requests,
                    "total_errors": self.total_errors,
                    "error_rate_percent": (self.total_errors / self.total_requests * 100) if self.total_requests > 0 else 0
                }
            )

            for pattern in self.patterns:
                pattern.report_stats()

    def start(self):
        """Start load generation"""
        self.request_thread = threading.Thread(target=self.generate_load)
        self.stats_thread = threading.Thread(target=self.report_stats)

        self.request_thread.start()
        self.stats_thread.start()

    def wait(self):
        """Wait for load generation to complete"""
        if self.request_thread:
            self.request_thread.join()

        self.running = False

        if self.stats_thread:
            self.stats_thread.join()

        # Final report
        logger.info(
            "Final load generation statistics",
            extra={
                "total_requests": self.total_requests,
                "total_errors": self.total_errors,
                "error_rate_percent": (self.total_errors / self.total_requests * 100) if self.total_requests > 0 else 0
            }
        )

        for pattern in self.patterns:
            pattern.report_stats()

# ============================================================================
# Main
# ============================================================================

def main():
    """Main entry point"""
    logger.info("Load Generator starting", extra={
        "target_url": TARGET_URL,
        "requests_per_second": REQUESTS_PER_SECOND,
        "duration_seconds": DURATION_SECONDS
    })

    # Create load patterns
    patterns = [
        NormalLoadPattern(REQUESTS_PER_SECOND * 0.4),
        SpikeLoadPattern(REQUESTS_PER_SECOND * 0.3),
        SlowResponsePattern(REQUESTS_PER_SECOND * 0.1),
        ErrorPattern(REQUESTS_PER_SECOND * 0.1),
        CreateItemsPattern(REQUESTS_PER_SECOND * 0.1),
    ]

    # Create and run load generator
    generator = LoadGenerator(TARGET_URL, patterns, DURATION_SECONDS)

    try:
        generator.start()
        generator.wait()
    except KeyboardInterrupt:
        logger.info("Load generation interrupted by user")
        generator.running = False
        generator.wait()
    except Exception as e:
        logger.error(f"Load generation failed: {str(e)}")
        raise

if __name__ == "__main__":
    main()
