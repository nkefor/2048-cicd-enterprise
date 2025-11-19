"""
Application tracking module with SQLite database.

Tracks job applications, statistics, and prevents duplicate submissions.
"""

import sqlite3
from pathlib import Path
from typing import List, Dict, Optional, Tuple
from datetime import datetime
from dataclasses import dataclass

from utils.logger import log_info, log_error, log_debug


@dataclass
class Application:
    """Job application record."""

    id: int
    job_title: str
    company: str
    location: str
    platform: str
    applied_at: str
    status: str
    url: str
    notes: Optional[str] = None


class ApplicationTracker:
    """Track job applications in SQLite database."""

    def __init__(self, db_path: str = "applications.db"):
        """
        Initialize ApplicationTracker.

        Args:
            db_path: Path to SQLite database file (default: 'applications.db').
        """
        self.db_path = Path(db_path)
        self.db_path.parent.mkdir(parents=True, exist_ok=True)
        self._initialize_database()
        log_debug(f"ApplicationTracker initialized with database: {db_path}")

    def _initialize_database(self) -> None:
        """Initialize database tables if they don't exist."""
        try:
            with sqlite3.connect(self.db_path) as conn:
                cursor = conn.cursor()

                cursor.execute(
                    """
                    CREATE TABLE IF NOT EXISTS applications (
                        id INTEGER PRIMARY KEY AUTOINCREMENT,
                        job_title TEXT NOT NULL,
                        company TEXT NOT NULL,
                        location TEXT,
                        platform TEXT NOT NULL,
                        applied_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
                        status TEXT DEFAULT 'applied',
                        url TEXT UNIQUE NOT NULL,
                        notes TEXT,
                        created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
                    )
                    """
                )

                cursor.execute(
                    """
                    CREATE TABLE IF NOT EXISTS application_history (
                        id INTEGER PRIMARY KEY AUTOINCREMENT,
                        application_id INTEGER NOT NULL,
                        status TEXT NOT NULL,
                        changed_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
                        notes TEXT,
                        FOREIGN KEY (application_id) REFERENCES applications(id)
                    )
                    """
                )

                cursor.execute(
                    """
                    CREATE TABLE IF NOT EXISTS statistics (
                        id INTEGER PRIMARY KEY AUTOINCREMENT,
                        date DATE UNIQUE NOT NULL,
                        applications_count INTEGER DEFAULT 0,
                        success_count INTEGER DEFAULT 0,
                        rejection_count INTEGER DEFAULT 0,
                        pending_count INTEGER DEFAULT 0,
                        updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
                    )
                    """
                )

                cursor.execute(
                    """
                    CREATE INDEX IF NOT EXISTS idx_url
                    ON applications(url)
                    """
                )

                cursor.execute(
                    """
                    CREATE INDEX IF NOT EXISTS idx_platform
                    ON applications(platform)
                    """
                )

                cursor.execute(
                    """
                    CREATE INDEX IF NOT EXISTS idx_company
                    ON applications(company)
                    """
                )

                conn.commit()
                log_info("Database tables initialized")

        except sqlite3.Error as e:
            log_error(f"Database initialization error: {e}")
            raise

    def track_application(
        self,
        job_title: str,
        company: str,
        location: str,
        platform: str,
        url: str,
        status: str = "applied",
        notes: Optional[str] = None,
    ) -> Tuple[bool, Optional[int]]:
        """
        Track a job application.

        Args:
            job_title: Job title.
            company: Company name.
            location: Job location.
            platform: Platform name (e.g., LinkedIn, Indeed).
            url: Job posting URL.
            status: Application status (default: 'applied').
            notes: Additional notes (optional).

        Returns:
            Tuple of (success, application_id).
        """
        try:
            with sqlite3.connect(self.db_path) as conn:
                cursor = conn.cursor()

                cursor.execute(
                    """
                    INSERT INTO applications
                    (job_title, company, location, platform, status, url, notes)
                    VALUES (?, ?, ?, ?, ?, ?, ?)
                    """,
                    (job_title, company, location, platform, status, url, notes),
                )

                conn.commit()
                application_id = cursor.lastrowid

                log_info(f"Application tracked: {company} - {job_title} (ID: {application_id})")
                return True, application_id

        except sqlite3.IntegrityError:
            log_warning(f"Duplicate application URL: {url}")
            return False, None

        except sqlite3.Error as e:
            log_error(f"Error tracking application: {e}")
            return False, None

    def has_applied_to(self, url: str) -> bool:
        """
        Check if already applied to job posting.

        Args:
            url: Job posting URL.

        Returns:
            True if already applied, False otherwise.
        """
        try:
            with sqlite3.connect(self.db_path) as conn:
                cursor = conn.cursor()

                cursor.execute(
                    "SELECT COUNT(*) FROM applications WHERE url = ?",
                    (url,),
                )

                count = cursor.fetchone()[0]
                has_applied = count > 0

                if has_applied:
                    log_debug(f"Duplicate application detected: {url}")

                return has_applied

        except sqlite3.Error as e:
            log_error(f"Error checking application: {e}")
            return False

    def update_application_status(
        self,
        application_id: int,
        status: str,
        notes: Optional[str] = None,
    ) -> bool:
        """
        Update application status.

        Args:
            application_id: Application ID.
            status: New status.
            notes: Optional notes (default: None).

        Returns:
            True if successful, False otherwise.
        """
        try:
            with sqlite3.connect(self.db_path) as conn:
                cursor = conn.cursor()

                cursor.execute(
                    "UPDATE applications SET status = ? WHERE id = ?",
                    (status, application_id),
                )

                cursor.execute(
                    """
                    INSERT INTO application_history
                    (application_id, status, notes)
                    VALUES (?, ?, ?)
                    """,
                    (application_id, status, notes),
                )

                conn.commit()

                log_debug(f"Application {application_id} status updated to: {status}")
                return True

        except sqlite3.Error as e:
            log_error(f"Error updating application status: {e}")
            return False

    def get_application(self, application_id: int) -> Optional[Application]:
        """
        Get application by ID.

        Args:
            application_id: Application ID.

        Returns:
            Application object or None if not found.
        """
        try:
            with sqlite3.connect(self.db_path) as conn:
                cursor = conn.cursor()

                cursor.execute(
                    """
                    SELECT id, job_title, company, location, platform, applied_at, status, url, notes
                    FROM applications WHERE id = ?
                    """,
                    (application_id,),
                )

                row = cursor.fetchone()

                if row:
                    return Application(*row)

                return None

        except sqlite3.Error as e:
            log_error(f"Error retrieving application: {e}")
            return None

    def get_applications_by_company(self, company: str) -> List[Application]:
        """
        Get all applications for a company.

        Args:
            company: Company name.

        Returns:
            List of Application objects.
        """
        try:
            with sqlite3.connect(self.db_path) as conn:
                cursor = conn.cursor()

                cursor.execute(
                    """
                    SELECT id, job_title, company, location, platform, applied_at, status, url, notes
                    FROM applications WHERE company = ? ORDER BY applied_at DESC
                    """,
                    (company,),
                )

                rows = cursor.fetchall()
                applications = [Application(*row) for row in rows]

                log_debug(f"Retrieved {len(applications)} applications for {company}")
                return applications

        except sqlite3.Error as e:
            log_error(f"Error retrieving applications by company: {e}")
            return []

    def get_applications_by_platform(self, platform: str) -> List[Application]:
        """
        Get all applications for a platform.

        Args:
            platform: Platform name.

        Returns:
            List of Application objects.
        """
        try:
            with sqlite3.connect(self.db_path) as conn:
                cursor = conn.cursor()

                cursor.execute(
                    """
                    SELECT id, job_title, company, location, platform, applied_at, status, url, notes
                    FROM applications WHERE platform = ? ORDER BY applied_at DESC
                    """,
                    (platform,),
                )

                rows = cursor.fetchall()
                applications = [Application(*row) for row in rows]

                log_debug(f"Retrieved {len(applications)} applications from {platform}")
                return applications

        except sqlite3.Error as e:
            log_error(f"Error retrieving applications by platform: {e}")
            return []

    def get_statistics(self) -> Dict[str, any]:
        """
        Get application statistics.

        Returns:
            Dictionary with statistics.
        """
        try:
            with sqlite3.connect(self.db_path) as conn:
                cursor = conn.cursor()

                cursor.execute("SELECT COUNT(*) FROM applications")
                total_count = cursor.fetchone()[0]

                cursor.execute("SELECT COUNT(*) FROM applications WHERE status = 'applied'")
                applied_count = cursor.fetchone()[0]

                cursor.execute("SELECT COUNT(*) FROM applications WHERE status = 'rejected'")
                rejected_count = cursor.fetchone()[0]

                cursor.execute("SELECT COUNT(*) FROM applications WHERE status = 'accepted'")
                accepted_count = cursor.fetchone()[0]

                cursor.execute("SELECT COUNT(*) FROM applications WHERE status = 'pending'")
                pending_count = cursor.fetchone()[0]

                cursor.execute(
                    """
                    SELECT platform, COUNT(*) as count FROM applications
                    GROUP BY platform ORDER BY count DESC
                    """
                )

                platform_stats = {row[0]: row[1] for row in cursor.fetchall()}

                cursor.execute(
                    """
                    SELECT company, COUNT(*) as count FROM applications
                    GROUP BY company ORDER BY count DESC LIMIT 10
                    """
                )

                top_companies = {row[0]: row[1] for row in cursor.fetchall()}

                stats = {
                    "total": total_count,
                    "applied": applied_count,
                    "rejected": rejected_count,
                    "accepted": accepted_count,
                    "pending": pending_count,
                    "success_rate": (
                        (accepted_count / total_count * 100) if total_count > 0 else 0
                    ),
                    "platforms": platform_stats,
                    "top_companies": top_companies,
                    "generated_at": datetime.now().isoformat(),
                }

                log_info(f"Statistics generated: {total_count} total applications")
                return stats

        except sqlite3.Error as e:
            log_error(f"Error generating statistics: {e}")
            return {}

    def get_recent_applications(self, limit: int = 10) -> List[Application]:
        """
        Get most recent applications.

        Args:
            limit: Number of applications to retrieve (default: 10).

        Returns:
            List of Application objects.
        """
        try:
            with sqlite3.connect(self.db_path) as conn:
                cursor = conn.cursor()

                cursor.execute(
                    """
                    SELECT id, job_title, company, location, platform, applied_at, status, url, notes
                    FROM applications ORDER BY applied_at DESC LIMIT ?
                    """,
                    (limit,),
                )

                rows = cursor.fetchall()
                applications = [Application(*row) for row in rows]

                log_debug(f"Retrieved {len(applications)} recent applications")
                return applications

        except sqlite3.Error as e:
            log_error(f"Error retrieving recent applications: {e}")
            return []

    def export_to_csv(self, filename: str) -> bool:
        """
        Export applications to CSV file.

        Args:
            filename: Output CSV filename.

        Returns:
            True if successful, False otherwise.
        """
        try:
            import csv

            with sqlite3.connect(self.db_path) as conn:
                cursor = conn.cursor()

                cursor.execute(
                    """
                    SELECT id, job_title, company, location, platform, applied_at, status, url, notes
                    FROM applications ORDER BY applied_at DESC
                    """
                )

                rows = cursor.fetchall()

            with open(filename, "w", newline="", encoding="utf-8") as csvfile:
                fieldnames = [
                    "id",
                    "job_title",
                    "company",
                    "location",
                    "platform",
                    "applied_at",
                    "status",
                    "url",
                    "notes",
                ]

                writer = csv.DictWriter(csvfile, fieldnames=fieldnames)
                writer.writeheader()

                for row in rows:
                    writer.writerow(dict(zip(fieldnames, row)))

            log_info(f"Applications exported to {filename}")
            return True

        except Exception as e:
            log_error(f"Error exporting to CSV: {e}")
            return False

    def clear_all(self) -> bool:
        """
        Clear all application records (use with caution).

        Returns:
            True if successful, False otherwise.
        """
        try:
            with sqlite3.connect(self.db_path) as conn:
                cursor = conn.cursor()

                cursor.execute("DELETE FROM application_history")
                cursor.execute("DELETE FROM applications")
                cursor.execute("DELETE FROM statistics")

                conn.commit()

                log_warning("All application records cleared")
                return True

        except sqlite3.Error as e:
            log_error(f"Error clearing records: {e}")
            return False


def log_warning(message: str) -> None:
    """Log warning message."""
    from utils.logger import log_warning as log_warn
    log_warn(message)
