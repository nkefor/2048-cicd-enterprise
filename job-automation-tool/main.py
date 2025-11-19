"""
Job Application Automation Tool - Main Entry Point

This is the production-ready main script with:
- Proper error handling
- Timeout protection
- Multi-platform support
- Real-time monitoring
"""

import sys
import os
import argparse
import signal
import time
from pathlib import Path
from typing import Dict, List

# Add project root to path
sys.path.insert(0, str(Path(__file__).parent))

from core.bot import JobApplicationBot
from core.config_manager import ConfigManager
from utils.logger import setup_logger, log_error, log_info, log_warning
from utils.validators import validate_config
from dashboard.metrics_tracker import MetricsTracker


class JobAutomationTool:
    """Main job automation tool orchestrator"""

    def __init__(self, config_path: str, debug: bool = False):
        """Initialize the automation tool"""
        self.config_path = config_path
        self.debug = debug
        self.logger = setup_logger('JobAutomationTool', debug=debug)
        self.bot = None
        self.metrics = MetricsTracker()
        self.interrupted = False

        # Setup signal handlers for graceful shutdown
        signal.signal(signal.SIGINT, self.signal_handler)
        signal.signal(signal.SIGTERM, self.signal_handler)

    def signal_handler(self, signum, frame):
        """Handle Ctrl+C and termination signals gracefully"""
        log_warning("Shutdown signal received. Finishing current application...")
        self.interrupted = True

        if self.bot:
            self.bot.stop()

        log_info("Saving progress and shutting down...")
        self.metrics.save_session()
        sys.exit(0)

    def load_and_validate_config(self) -> Dict:
        """Load and validate configuration"""
        log_info(f"Loading configuration from: {self.config_path}")

        try:
            config_manager = ConfigManager(self.config_path)
            config = config_manager.load_config()

            # Validate configuration
            is_valid, errors = validate_config(config)
            if not is_valid:
                log_error("Configuration validation failed:")
                for error in errors:
                    log_error(f"  - {error}")
                sys.exit(1)

            log_info("Configuration loaded and validated successfully")
            return config

        except FileNotFoundError:
            log_error(f"Configuration file not found: {self.config_path}")
            log_info("Please create config.json from config.example.json")
            sys.exit(1)
        except Exception as e:
            log_error(f"Failed to load configuration: {e}")
            sys.exit(1)

    def get_enabled_platforms(self, config: Dict) -> List[str]:
        """Get list of enabled platforms from config"""
        platforms = config.get('platforms', {})
        enabled = [name for name, enabled in platforms.items() if enabled]

        if not enabled:
            log_warning("No platforms enabled in configuration!")
            return []

        log_info(f"Enabled platforms ({len(enabled)}): {', '.join(enabled)}")
        return enabled

    def run(self):
        """Main execution loop"""
        start_time = time.time()

        try:
            # Load configuration
            config = self.load_and_validate_config()

            # Get enabled platforms
            enabled_platforms = self.get_enabled_platforms(config)
            if not enabled_platforms:
                log_error("No platforms to process. Exiting.")
                return

            # Initialize bot
            log_info("Initializing Job Application Bot...")
            self.bot = JobApplicationBot(config, debug=self.debug)

            # Start automation
            log_info("=" * 80)
            log_info("Starting Job Application Automation")
            log_info("=" * 80)
            log_info(f"Target: {len(enabled_platforms)} platforms")
            log_info(f"Max applications: {config['automation']['max_applications_per_run']}")
            log_info("=" * 80)

            # Track overall statistics
            total_applications = 0
            total_success = 0
            total_failures = 0
            platform_results = {}

            # Process each platform
            for idx, platform_name in enumerate(enabled_platforms, 1):
                if self.interrupted:
                    log_warning("Interrupted by user. Stopping...")
                    break

                log_info("")
                log_info("=" * 80)
                log_info(f"Platform {idx}/{len(enabled_platforms)}: {platform_name.upper()}")
                log_info("=" * 80)

                try:
                    # Process platform with timeout protection
                    result = self.bot.process_platform(
                        platform_name,
                        timeout_seconds=600  # 10 minute timeout per platform
                    )

                    # Track results
                    platform_results[platform_name] = result
                    total_applications += result.get('applications', 0)
                    total_success += result.get('success', 0)
                    total_failures += result.get('failures', 0)

                    # Log platform results
                    log_info(f"{platform_name} Results:")
                    log_info(f"  Applications: {result.get('applications', 0)}")
                    log_info(f"  Success: {result.get('success', 0)}")
                    log_info(f"  Failures: {result.get('failures', 0)}")
                    log_info(f"  Success Rate: {result.get('success_rate', 0):.1f}%")

                    # Update metrics
                    self.metrics.record_platform_run(platform_name, result)

                except TimeoutError:
                    log_error(f"{platform_name}: Platform timed out after 10 minutes")
                    platform_results[platform_name] = {'error': 'timeout'}
                    total_failures += 1

                except Exception as e:
                    log_error(f"{platform_name}: Unexpected error - {e}")
                    platform_results[platform_name] = {'error': str(e)}
                    total_failures += 1

                # Check if we've hit max applications
                if total_applications >= config['automation']['max_applications_per_run']:
                    log_info(f"Reached maximum applications ({total_applications}). Stopping.")
                    break

            # Final summary
            elapsed_time = time.time() - start_time
            self.print_final_summary(
                enabled_platforms,
                platform_results,
                total_applications,
                total_success,
                total_failures,
                elapsed_time
            )

            # Save metrics
            self.metrics.save_session()

        except KeyboardInterrupt:
            log_warning("Interrupted by user (Ctrl+C)")
            if self.bot:
                self.bot.stop()
        except Exception as e:
            log_error(f"Fatal error: {e}")
            import traceback
            log_error(traceback.format_exc())
            sys.exit(1)
        finally:
            # Cleanup
            if self.bot:
                self.bot.cleanup()
            log_info("Job automation completed")

    def print_final_summary(self, platforms, results, total_apps, success, failures, elapsed):
        """Print final summary statistics"""
        log_info("")
        log_info("=" * 80)
        log_info("FINAL SUMMARY")
        log_info("=" * 80)
        log_info(f"Duration: {elapsed/60:.1f} minutes")
        log_info(f"Platforms processed: {len(platforms)}")
        log_info(f"Total applications: {total_apps}")
        log_info(f"Successful: {success}")
        log_info(f"Failed: {failures}")

        if total_apps > 0:
            success_rate = (success / total_apps) * 100
            log_info(f"Overall success rate: {success_rate:.1f}%")

        log_info("")
        log_info("Platform Breakdown:")
        for platform, result in results.items():
            if 'error' in result:
                log_info(f"  {platform}: ERROR - {result['error']}")
            else:
                apps = result.get('applications', 0)
                succ = result.get('success', 0)
                log_info(f"  {platform}: {apps} applications, {succ} successful")

        log_info("=" * 80)
        log_info("View detailed metrics at: http://localhost:5000")
        log_info("=" * 80)


def main():
    """Entry point"""
    parser = argparse.ArgumentParser(
        description='Job Application Automation Tool',
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog="""
Examples:
  python main.py                          # Run with default config
  python main.py --config my_config.json  # Run with custom config
  python main.py --debug --verbose        # Run with debug logging
  python main.py --platforms indeed dice  # Run specific platforms only
        """
    )

    parser.add_argument(
        '--config',
        type=str,
        default='config.json',
        help='Path to configuration file (default: config.json)'
    )

    parser.add_argument(
        '--debug',
        action='store_true',
        help='Enable debug logging'
    )

    parser.add_argument(
        '--verbose',
        action='store_true',
        help='Enable verbose output'
    )

    parser.add_argument(
        '--platforms',
        nargs='+',
        help='Specific platforms to run (overrides config)'
    )

    parser.add_argument(
        '--max-apps',
        type=int,
        help='Maximum applications per run (overrides config)'
    )

    parser.add_argument(
        '--headless',
        action='store_true',
        help='Run browser in headless mode (overrides config)'
    )

    args = parser.parse_args()

    # Print banner
    print("=" * 80)
    print("  JOB APPLICATION AUTOMATION TOOL v2.0")
    print("  Production-Ready Job Search Automation")
    print("=" * 80)
    print("")

    # Check if config exists
    if not os.path.exists(args.config):
        print(f"ERROR: Configuration file not found: {args.config}")
        print("")
        print("Please create a configuration file:")
        print(f"  cp config.example.json {args.config}")
        print(f"  nano {args.config}")
        print("")
        sys.exit(1)

    # Initialize and run tool
    tool = JobAutomationTool(
        config_path=args.config,
        debug=args.debug or args.verbose
    )

    tool.run()


if __name__ == '__main__':
    main()
