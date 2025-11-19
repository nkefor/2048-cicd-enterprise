"""
Metrics tracking system for job automation dashboard.

Tracks applications, success rates, and platform health metrics.
Stores data in JSON files for dashboard visualization.
"""

import json
import os
from pathlib import Path
from typing import Dict, List, Optional
from datetime import datetime, timedelta
from collections import defaultdict

from utils.logger import log_info, log_error, log_debug, log_warning


class MetricsTracker:
    """Track and persist job application metrics."""

    def __init__(self, data_dir: str = "data/metrics"):
        """
        Initialize metrics tracker.

        Args:
            data_dir: Directory to store metrics files
        """
        self.data_dir = Path(data_dir)
        self.data_dir.mkdir(parents=True, exist_ok=True)

        self.applications_file = self.data_dir / "applications.json"
        self.platforms_file = self.data_dir / "platforms.json"
        self.stats_file = self.data_dir / "stats.json"
        self.session_file = self.data_dir / "current_session.json"

        # Load existing data
        self.applications = self._load_json(self.applications_file, [])
        self.platforms = self._load_json(self.platforms_file, {})
        self.stats = self._load_json(self.stats_file, {})
        self.current_session = {
            'start_time': datetime.now().isoformat(),
            'applications': 0,
            'successes': 0,
            'failures': 0,
            'platforms': {}
        }

        log_info(f"[METRICS] Initialized tracker with {len(self.applications)} applications in history")

    def _load_json(self, filepath: Path, default=None):
        """Load JSON file with fallback to default."""
        try:
            if filepath.exists():
                with open(filepath, 'r') as f:
                    return json.load(f)
        except Exception as e:
            log_warning(f"Failed to load {filepath}: {e}")
        return default if default is not None else {}

    def _save_json(self, filepath: Path, data):
        """Save data to JSON file."""
        try:
            with open(filepath, 'w') as f:
                json.dump(data, f, indent=2, default=str)
        except Exception as e:
            log_error(f"Failed to save {filepath}: {e}")

    def record_application(self, platform: str, job_title: str, company: str,
                          success: bool, details: Dict = None) -> None:
        """
        Record a job application.

        Args:
            platform: Platform name
            job_title: Job title
            company: Company name
            success: Whether application was successful
            details: Additional details dictionary
        """
        application = {
            'timestamp': datetime.now().isoformat(),
            'platform': platform.lower(),
            'job_title': job_title,
            'company': company,
            'success': success,
            'details': details or {}
        }

        self.applications.append(application)
        self._save_json(self.applications_file, self.applications)

        # Update current session
        self.current_session['applications'] += 1
        if success:
            self.current_session['successes'] += 1
        else:
            self.current_session['failures'] += 1

        if platform not in self.current_session['platforms']:
            self.current_session['platforms'][platform] = {
                'applications': 0,
                'successes': 0,
                'failures': 0
            }

        self.current_session['platforms'][platform]['applications'] += 1
        if success:
            self.current_session['platforms'][platform]['successes'] += 1
        else:
            self.current_session['platforms'][platform]['failures'] += 1

        log_debug(f"[METRICS] Recorded application: {job_title} at {company} ({platform})")

    def record_platform_run(self, platform: str, result: Dict) -> None:
        """
        Record platform run results.

        Args:
            platform: Platform name
            result: Result dictionary with 'applications', 'success', 'failures' keys
        """
        platform = platform.lower()

        if platform not in self.platforms:
            self.platforms[platform] = {
                'runs': [],
                'total_applications': 0,
                'total_successes': 0,
                'total_failures': 0,
                'success_rate': 0.0
            }

        run_record = {
            'timestamp': datetime.now().isoformat(),
            'applications': result.get('applications', 0),
            'successes': result.get('success', 0),
            'failures': result.get('failures', 0),
            'success_rate': result.get('success_rate', 0),
            'error': result.get('error')
        }

        self.platforms[platform]['runs'].append(run_record)
        self.platforms[platform]['total_applications'] += run_record['applications']
        self.platforms[platform]['total_successes'] += run_record['successes']
        self.platforms[platform]['total_failures'] += run_record['failures']

        # Calculate overall success rate
        if self.platforms[platform]['total_applications'] > 0:
            self.platforms[platform]['success_rate'] = (
                self.platforms[platform]['total_successes'] /
                self.platforms[platform]['total_applications'] * 100
            )

        # Keep only last 100 runs
        if len(self.platforms[platform]['runs']) > 100:
            self.platforms[platform]['runs'] = self.platforms[platform]['runs'][-100:]

        self._save_json(self.platforms_file, self.platforms)

        log_info(
            f"[METRICS] Platform {platform}: "
            f"{run_record['applications']} applications, "
            f"{run_record['successes']} successes"
        )

    def get_platform_health(self) -> Dict:
        """
        Get health status of all platforms.

        Returns:
            Dictionary with platform health metrics
        """
        health = {}

        for platform, data in self.platforms.items():
            if not data['runs']:
                continue

            recent_runs = data['runs'][-10:]  # Last 10 runs
            recent_success = sum(r['successes'] for r in recent_runs)
            recent_total = sum(r['applications'] for r in recent_runs)

            recent_rate = (recent_success / recent_total * 100) if recent_total > 0 else 0

            health[platform] = {
                'overall_success_rate': data['success_rate'],
                'recent_success_rate': recent_rate,
                'total_applications': data['total_applications'],
                'total_successes': data['total_successes'],
                'status': self._get_platform_status(recent_rate),
                'last_run': data['runs'][-1]['timestamp'] if data['runs'] else None
            }

        return health

    def _get_platform_status(self, success_rate: float) -> str:
        """Get platform status based on success rate."""
        if success_rate >= 80:
            return "healthy"
        elif success_rate >= 50:
            return "degraded"
        else:
            return "unhealthy"

    def get_recent_applications(self, limit: int = 50, platform: Optional[str] = None) -> List[Dict]:
        """
        Get recent applications.

        Args:
            limit: Maximum number to return
            platform: Filter by platform (optional)

        Returns:
            List of recent applications
        """
        apps = self.applications

        if platform:
            apps = [a for a in apps if a['platform'].lower() == platform.lower()]

        return apps[-limit:]

    def get_statistics(self) -> Dict:
        """
        Get overall statistics.

        Returns:
            Dictionary with aggregated statistics
        """
        total_apps = len(self.applications)
        successful_apps = sum(1 for a in self.applications if a['success'])
        failed_apps = total_apps - successful_apps

        success_rate = (successful_apps / total_apps * 100) if total_apps > 0 else 0

        # Platform breakdown
        by_platform = defaultdict(lambda: {'total': 0, 'success': 0})
        for app in self.applications:
            platform = app['platform']
            by_platform[platform]['total'] += 1
            if app['success']:
                by_platform[platform]['success'] += 1

        platform_stats = {}
        for platform, counts in by_platform.items():
            rate = (counts['success'] / counts['total'] * 100) if counts['total'] > 0 else 0
            platform_stats[platform] = {
                'total': counts['total'],
                'successful': counts['success'],
                'failed': counts['total'] - counts['success'],
                'success_rate': rate
            }

        # Time analysis
        today_apps = self._get_apps_since(timedelta(days=1))
        week_apps = self._get_apps_since(timedelta(days=7))
        month_apps = self._get_apps_since(timedelta(days=30))

        return {
            'total_applications': total_apps,
            'successful_applications': successful_apps,
            'failed_applications': failed_apps,
            'overall_success_rate': success_rate,
            'by_platform': platform_stats,
            'today': {
                'total': len(today_apps),
                'successful': sum(1 for a in today_apps if a['success'])
            },
            'this_week': {
                'total': len(week_apps),
                'successful': sum(1 for a in week_apps if a['success'])
            },
            'this_month': {
                'total': len(month_apps),
                'successful': sum(1 for a in month_apps if a['success'])
            },
            'last_updated': datetime.now().isoformat()
        }

    def _get_apps_since(self, delta: timedelta) -> List[Dict]:
        """Get applications since time delta."""
        cutoff = datetime.now() - delta

        return [
            a for a in self.applications
            if datetime.fromisoformat(a['timestamp']) > cutoff
        ]

    def save_session(self) -> None:
        """Save current session metrics."""
        self.current_session['end_time'] = datetime.now().isoformat()
        self._save_json(self.session_file, self.current_session)

        # Also save to stats
        self.stats[self.current_session['start_time']] = self.current_session
        self._save_json(self.stats_file, self.stats)

        log_info(f"[METRICS] Session saved with {self.current_session['successes']} successes")

    def get_chart_data(self, days: int = 7) -> Dict:
        """
        Get data for charts.

        Args:
            days: Number of days to include

        Returns:
            Dictionary with chart data
        """
        cutoff = datetime.now() - timedelta(days=days)

        # Group by date
        by_date = defaultdict(lambda: {'total': 0, 'success': 0})

        for app in self.applications:
            app_time = datetime.fromisoformat(app['timestamp'])
            if app_time < cutoff:
                continue

            date_key = app_time.strftime('%Y-%m-%d')
            by_date[date_key]['total'] += 1
            if app['success']:
                by_date[date_key]['success'] += 1

        # Sort by date
        sorted_dates = sorted(by_date.keys())

        return {
            'dates': sorted_dates,
            'totals': [by_date[d]['total'] for d in sorted_dates],
            'successes': [by_date[d]['success'] for d in sorted_dates],
            'failures': [by_date[d]['total'] - by_date[d]['success'] for d in sorted_dates]
        }

    def export_json(self, filepath: str) -> bool:
        """
        Export all metrics to JSON file.

        Args:
            filepath: Path to export to

        Returns:
            True if successful
        """
        try:
            data = {
                'statistics': self.get_statistics(),
                'platform_health': self.get_platform_health(),
                'recent_applications': self.get_recent_applications(limit=100),
                'chart_data': self.get_chart_data(days=30),
                'export_time': datetime.now().isoformat()
            }

            with open(filepath, 'w') as f:
                json.dump(data, f, indent=2, default=str)

            log_info(f"[METRICS] Exported to {filepath}")
            return True

        except Exception as e:
            log_error(f"[METRICS] Export failed: {e}")
            return False

    def __repr__(self) -> str:
        """String representation."""
        stats = self.get_statistics()
        return (
            f"MetricsTracker("
            f"total_apps={stats['total_applications']}, "
            f"success_rate={stats['overall_success_rate']:.1f}%"
            f")"
        )
